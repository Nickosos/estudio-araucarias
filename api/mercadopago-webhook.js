const { createClient } = require("@supabase/supabase-js");
const { MercadoPagoConfig, Payment } = require("mercadopago");

module.exports = async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Método no permitido" });
  const paymentId = req.body?.data?.id || req.query?.["data.id"] || req.query?.id;
  if (!paymentId) return res.status(400).json({ error: "Falta el identificador del pago" });

  const mp = new MercadoPagoConfig({ accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN });
  const payment = await new Payment(mp).get({ id: paymentId });
  const orderId = payment.external_reference;
  if (!orderId) return res.status(200).json({ received: true });

  const db = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
  const statusMap = { approved: "approved", rejected: "rejected", cancelled: "rejected", pending: "pending", in_process: "pending" };
  const paymentStatus = statusMap[payment.status] || "pending";
  const { data: order, error } = await db.from("orders").select("id, status, stock_reserved").eq("id", orderId).single();
  if (error) return res.status(404).json({ error: "Pedido no encontrado" });

  const updates = { payment_status: paymentStatus };
  if (paymentStatus === "approved") updates.status = "confirmed";
  if (paymentStatus === "rejected" && order.stock_reserved) {
    const { data: items, error: itemsError } = await db.from("order_items").select("product_id, quantity").eq("order_id", orderId);
    if (itemsError) return res.status(500).json({ error: "No se pudo recuperar el detalle del pedido" });
    const { error: releaseError } = await db.rpc("release_order_stock", { p_items: items });
    if (releaseError) return res.status(500).json({ error: "No se pudo liberar el stock" });
    updates.stock_reserved = false;
    updates.status = "cancelled";
  }
  const { error: updateError } = await db.from("orders").update(updates).eq("id", orderId);
  if (updateError) return res.status(500).json({ error: "No se pudo actualizar el pedido" });
  return res.status(200).json({ received: true });
};
