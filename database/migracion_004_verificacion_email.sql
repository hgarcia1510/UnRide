-- UniRaite - Migración 004: verificación de correo
-- Para bases existentes. Se aplica una sola vez por deploy/actualizar_backend.sh.
-- Los usuarios ya existentes quedan verificados para conservar su acceso.
ALTER TABLE Usuarios
    ADD COLUMN email_verificado BOOLEAN NOT NULL DEFAULT FALSE AFTER correo_institucional;

UPDATE Usuarios SET email_verificado = TRUE;

CREATE TABLE IF NOT EXISTS Verificaciones_Email (
    id_usuario       INT PRIMARY KEY,
    codigo_hash      CHAR(64) NOT NULL,
    expira           DATETIME NOT NULL,
    enviado_en       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    intentos         TINYINT UNSIGNED NOT NULL DEFAULT 0,
    envios_ventana   TINYINT UNSIGNED NOT NULL DEFAULT 1,
    ventana_envios   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_verificaciones_usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB;
