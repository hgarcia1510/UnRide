-- UniRaite - Migración 002: foto de perfil
-- Para bases creadas antes de esta versión. Ejecutar una sola vez:
--   mysql -u root -p uniraite < migracion_002_foto_perfil.sql
ALTER TABLE Usuarios ADD COLUMN foto_url VARCHAR(255) NULL AFTER telefono;
