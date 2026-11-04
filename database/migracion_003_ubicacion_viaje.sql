-- UniRaite - Migración 003: ubicación en vivo del chofer
-- Para bases creadas antes de esta versión. Ejecutar una sola vez:
--   mysql -u root -p uniraite < migracion_003_ubicacion_viaje.sql
CREATE TABLE IF NOT EXISTS Ubicacion_Viaje (
    id_viaje       INT PRIMARY KEY,
    latitud        DECIMAL(9,6) NOT NULL,
    longitud       DECIMAL(9,6) NOT NULL,
    rumbo          SMALLINT NULL,
    actualizada    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_ubicacion_viaje FOREIGN KEY (id_viaje) REFERENCES Viajes(id_viaje) ON DELETE CASCADE
) ENGINE=InnoDB;
