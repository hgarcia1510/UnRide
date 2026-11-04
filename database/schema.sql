-- =====================================================================
-- UniRaite - Esquema de base de datos (MySQL 8.0+)
-- Equipo: JAH Devs
-- =====================================================================
-- Ejecutar con:  mysql -u root -p < schema.sql
-- =====================================================================

DROP DATABASE IF EXISTS uniraite;
CREATE DATABASE uniraite CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE uniraite;

-- ---------------------------------------------------------------------
-- Usuarios: toda la comunidad (Administradores, Choferes y Pasajeros).
-- Roles dinámicos: un mismo usuario puede ser chofer o pasajero según el
-- viaje; solo se distingue al Administrador con la columna `rol`.
-- estado_cuenta 'Pendiente' = espera validación manual del administrador
-- (cuando no usa correo institucional).
-- ---------------------------------------------------------------------
CREATE TABLE Usuarios (
    id_usuario            INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo       VARCHAR(100) NOT NULL,
    correo_institucional  VARCHAR(150) NOT NULL,
    password_hash         VARCHAR(255) NOT NULL,
    telefono              VARCHAR(20)  NULL,
    foto_url              VARCHAR(255) NULL,
    calificacion_promedio DECIMAL(3,2) NOT NULL DEFAULT 5.00,
    estado_cuenta         ENUM('Activo','Suspendido','Pendiente') NOT NULL DEFAULT 'Activo',
    rol                   ENUM('Usuario','Administrador') NOT NULL DEFAULT 'Usuario',
    fecha_registro        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_usuarios_correo UNIQUE (correo_institucional),
    CONSTRAINT chk_usuarios_calificacion CHECK (calificacion_promedio BETWEEN 1.00 AND 5.00)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Vehiculos: autos de los usuarios que operan como choferes.
-- ---------------------------------------------------------------------
CREATE TABLE Vehiculos (
    id_vehiculo       INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario        INT NOT NULL,
    placas            VARCHAR(15)  NOT NULL,
    modelo_color      VARCHAR(100) NOT NULL,
    capacidad_maxima  INT NOT NULL,
    activo            BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_vehiculos_placas UNIQUE (placas),
    CONSTRAINT chk_vehiculos_capacidad CHECK (capacidad_maxima BETWEEN 1 AND 8),
    CONSTRAINT fk_vehiculos_usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Viajes: rutas publicadas por los choferes.
-- asientos_disponibles inicia con capacidad_maxima del auto y se resta
-- con cada solicitud aceptada (lo hacen los triggers de abajo).
-- ---------------------------------------------------------------------
CREATE TABLE Viajes (
    id_viaje              INT AUTO_INCREMENT PRIMARY KEY,
    id_chofer             INT NOT NULL,
    id_vehiculo           INT NOT NULL,
    punto_origen          VARCHAR(150) NOT NULL,
    punto_destino         VARCHAR(150) NOT NULL,
    fecha_hora_salida     DATETIME NOT NULL,
    asientos_disponibles  INT NOT NULL,
    notas                 VARCHAR(255) NULL,
    estado_viaje          ENUM('Programado','En Curso','Finalizado','Cancelado')
                          NOT NULL DEFAULT 'Programado',
    fecha_creacion        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_viajes_asientos CHECK (asientos_disponibles >= 0),
    CONSTRAINT fk_viajes_chofer   FOREIGN KEY (id_chofer)   REFERENCES Usuarios(id_usuario),
    CONSTRAINT fk_viajes_vehiculo FOREIGN KEY (id_vehiculo) REFERENCES Vehiculos(id_vehiculo),
    INDEX idx_viajes_busqueda (estado_viaje, fecha_hora_salida),
    INDEX idx_viajes_destino (punto_destino)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Solicitudes_Asiento: reservas de pasajeros (tabla intermedia).
-- 'Cancelada' = el pasajero se dio de baja (libera su asiento).
-- ---------------------------------------------------------------------
CREATE TABLE Solicitudes_Asiento (
    id_solicitud     INT AUTO_INCREMENT PRIMARY KEY,
    id_viaje         INT NOT NULL,
    id_pasajero      INT NOT NULL,
    estado_solicitud ENUM('Pendiente','Aceptada','Rechazada','Cancelada')
                     NOT NULL DEFAULT 'Pendiente',
    fecha_solicitud  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_solicitud_viaje_pasajero UNIQUE (id_viaje, id_pasajero),
    CONSTRAINT fk_solicitudes_viaje    FOREIGN KEY (id_viaje)    REFERENCES Viajes(id_viaje) ON DELETE CASCADE,
    CONSTRAINT fk_solicitudes_pasajero FOREIGN KEY (id_pasajero) REFERENCES Usuarios(id_usuario)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Rutas_Guardadas: destinos que un pasajero quiere vigilar para recibir
-- notificación cuando un chofer publique un viaje coincidente.
-- ---------------------------------------------------------------------
CREATE TABLE Rutas_Guardadas (
    id_ruta       INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario    INT NOT NULL,
    punto_origen  VARCHAR(150) NULL,
    punto_destino VARCHAR(150) NOT NULL,
    CONSTRAINT fk_rutas_usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Notificaciones: bandeja de notificaciones de cada usuario.
-- ---------------------------------------------------------------------
CREATE TABLE Notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario      INT NOT NULL,
    titulo          VARCHAR(120) NOT NULL,
    mensaje         VARCHAR(255) NOT NULL,
    id_viaje        INT NULL,
    leida           BOOLEAN NOT NULL DEFAULT FALSE,
    fecha           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_notif_viaje   FOREIGN KEY (id_viaje)   REFERENCES Viajes(id_viaje) ON DELETE SET NULL,
    INDEX idx_notif_usuario (id_usuario, leida)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Resenas: calificaciones entre chofer y pasajeros al finalizar un viaje.
-- ---------------------------------------------------------------------
CREATE TABLE Resenas (
    id_resena     INT AUTO_INCREMENT PRIMARY KEY,
    id_viaje      INT NOT NULL,
    id_autor      INT NOT NULL,
    id_evaluado   INT NOT NULL,
    calificacion  TINYINT NOT NULL,
    comentario    VARCHAR(255) NULL,
    fecha         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_resenas_calificacion CHECK (calificacion BETWEEN 1 AND 5),
    CONSTRAINT uq_resena UNIQUE (id_viaje, id_autor, id_evaluado),
    CONSTRAINT fk_resenas_viaje    FOREIGN KEY (id_viaje)    REFERENCES Viajes(id_viaje) ON DELETE CASCADE,
    CONSTRAINT fk_resenas_autor    FOREIGN KEY (id_autor)    REFERENCES Usuarios(id_usuario),
    CONSTRAINT fk_resenas_evaluado FOREIGN KEY (id_evaluado) REFERENCES Usuarios(id_usuario)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Ubicacion_Viaje: última posición del chofer mientras el viaje está En Curso.
-- ---------------------------------------------------------------------
CREATE TABLE Ubicacion_Viaje (
    id_viaje       INT PRIMARY KEY,
    latitud        DECIMAL(9,6) NOT NULL,
    longitud       DECIMAL(9,6) NOT NULL,
    rumbo          SMALLINT NULL,
    actualizada    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_ubicacion_viaje FOREIGN KEY (id_viaje) REFERENCES Viajes(id_viaje) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- TRIGGERS - Reglas de negocio garantizadas por la base de datos
-- =====================================================================
DELIMITER $$

-- Al publicar un viaje, los asientos disponibles salen del vehículo.
-- También valida que el vehículo pertenezca al chofer.
CREATE TRIGGER trg_viajes_before_insert
BEFORE INSERT ON Viajes
FOR EACH ROW
BEGIN
    DECLARE v_capacidad INT;
    DECLARE v_duenio INT;

    SELECT capacidad_maxima, id_usuario INTO v_capacidad, v_duenio
    FROM Vehiculos WHERE id_vehiculo = NEW.id_vehiculo;

    IF v_duenio IS NULL OR v_duenio <> NEW.id_chofer THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El vehiculo no pertenece al chofer';
    END IF;

    IF NEW.asientos_disponibles IS NULL OR NEW.asientos_disponibles > v_capacidad
       OR NEW.asientos_disponibles < 1 THEN
        SET NEW.asientos_disponibles = v_capacidad;
    END IF;
END$$

-- Evita que alguien solicite asiento en su propio viaje.
CREATE TRIGGER trg_solicitudes_before_insert
BEFORE INSERT ON Solicitudes_Asiento
FOR EACH ROW
BEGIN
    IF (SELECT id_chofer FROM Viajes WHERE id_viaje = NEW.id_viaje) = NEW.id_pasajero THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El chofer no puede reservar en su propio viaje';
    END IF;
    IF NEW.estado_solicitud = 'Aceptada' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una solicitud nueva debe iniciar como Pendiente';
    END IF;
END$$

-- PREVENCIÓN DE OVERBOOKING:
-- Al aceptar una solicitud se bloquea la fila del viaje (FOR UPDATE) y se
-- rechaza si ya no hay asientos. Al cancelar/rechazar una ya aceptada,
-- se libera el asiento.
CREATE TRIGGER trg_solicitudes_before_update
BEFORE UPDATE ON Solicitudes_Asiento
FOR EACH ROW
BEGIN
    DECLARE v_asientos INT;

    IF NEW.estado_solicitud = 'Aceptada' AND OLD.estado_solicitud <> 'Aceptada' THEN
        SELECT asientos_disponibles INTO v_asientos
        FROM Viajes WHERE id_viaje = NEW.id_viaje FOR UPDATE;

        IF v_asientos <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overbooking: el viaje ya no tiene asientos disponibles';
        END IF;

        UPDATE Viajes SET asientos_disponibles = asientos_disponibles - 1
        WHERE id_viaje = NEW.id_viaje;

    ELSEIF OLD.estado_solicitud = 'Aceptada' AND NEW.estado_solicitud <> 'Aceptada' THEN
        UPDATE Viajes SET asientos_disponibles = asientos_disponibles + 1
        WHERE id_viaje = NEW.id_viaje;
    END IF;
END$$

-- Recalcula la calificación promedio del usuario evaluado.
CREATE TRIGGER trg_resenas_after_insert
AFTER INSERT ON Resenas
FOR EACH ROW
BEGIN
    UPDATE Usuarios
    SET calificacion_promedio = (
        SELECT ROUND(AVG(calificacion), 2) FROM Resenas WHERE id_evaluado = NEW.id_evaluado
    )
    WHERE id_usuario = NEW.id_evaluado;
END$$

DELIMITER ;
