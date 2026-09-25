# Estudio Araucarias

Proyecto de tienda para insumos de reparación automotriz.

La carpeta permanente del proyecto es:

`D:\Estudio-Araucarias`

El esquema de base de datos recuperado está en `supabase/schema.sql`.

Importante: la antigua carpeta `D:\$WINDOWS.~TMP\Work` era temporal y fue limpiada por Windows. Los archivos HTML, CSS y JavaScript que estaban allí no pudieron moverse porque ya no existían en el disco. Ejecuta el esquema de Supabase desde esta carpeta y conserva este proyecto en una ubicación permanente o en GitHub.

## Conectar Supabase

1. Abre Supabase SQL Editor.
2. Copia todo `supabase/schema.sql`.
3. Pulsa Run.
4. Crea el usuario dueño en Authentication > Users.
5. Ejecuta:

```sql
insert into public.admin_users (user_id)
values ('UUID_DEL_USUARIO');
```

No pongas contraseñas, tokens ni claves `service_role` en archivos públicos.
