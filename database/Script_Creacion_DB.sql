/* ============================================================================
   RentaTica - Script de creacion de base de datos 
   ============================================================================ */

IF DB_ID('RentaTicaDB') IS NULL
BEGIN
    CREATE DATABASE RentaTicaDB;
END
GO

USE RentaTicaDB;
GO

IF SCHEMA_ID('renta') IS NULL
BEGIN
    EXEC('CREATE SCHEMA renta'); /*Una carpeta para llevar el control de las tablas, sirve en proyectos grandes.*/
END
GO

/* ============================================================================*/

CREATE TABLE renta.Rol (
    rol_id   INT IDENTITY(1,1) PRIMARY KEY,
    nombre   VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_Rol_nombre   UNIQUE (nombre),
    CONSTRAINT CHK_Rol_nombre  CHECK (nombre IN ('Administrador','Operador','Cliente'))
);
GO

CREATE TABLE renta.MetodoPago (
    metodo_pago_id INT IDENTITY(1,1) PRIMARY KEY,
    nombre         VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_MetodoPago_nombre  UNIQUE (nombre),
    CONSTRAINT CHK_MetodoPago_nombre CHECK (nombre IN ('Efectivo','Tarjeta','SINPE Movil'))
);
GO

CREATE TABLE renta.Negocio (
    negocio_id     INT IDENTITY(1,1) PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    direccion      VARCHAR(200) NULL,
    telefono       VARCHAR(20)  NULL,
    email_contacto VARCHAR(100) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT GETDATE(),
    estado         VARCHAR(20) NOT NULL DEFAULT 'Activo',
    CONSTRAINT UQ_Negocio_email  UNIQUE (email_contacto),
    CONSTRAINT CHK_Negocio_estado CHECK (estado IN ('Activo','Suspendido'))
);
GO

/* ============================================================================
   2. Usuario (depende de Rol y Negocio)
   ============================================================================ */

CREATE TABLE renta.Usuario (
    usuario_id          INT IDENTITY(1,1) PRIMARY KEY,
    nombre_completo      VARCHAR(100) NOT NULL,
    email                VARCHAR(100) NOT NULL,
    password_hash        VARCHAR(256) NOT NULL,
    telefono             VARCHAR(20)  NULL,
    documento_identidad  VARCHAR(30)  NULL,
    rol_id               INT NOT NULL,
    negocio_id           INT NULL,
    fecha_creacion       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_Usuario_email      UNIQUE (email),
    CONSTRAINT FK_Usuario_Rol        FOREIGN KEY (rol_id) REFERENCES renta.Rol(rol_id),
    CONSTRAINT FK_Usuario_Negocio    FOREIGN KEY (negocio_id) REFERENCES renta.Negocio(negocio_id)
);
GO

/* ============================================================================
   3. CategoriaEquipo (depende de Negocio)
   ============================================================================ */

CREATE TABLE renta.CategoriaEquipo (
    categoria_id   INT IDENTITY(1,1) PRIMARY KEY,
    negocio_id     INT NOT NULL,
    nombre         VARCHAR(80) NOT NULL,
    descripcion    VARCHAR(300) NULL,
    tarifa_hora    DECIMAL(10,2) NOT NULL,
    tarifa_dia     DECIMAL(10,2) NOT NULL,
    monto_deposito DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_CategoriaEquipo_Negocio   FOREIGN KEY (negocio_id) REFERENCES renta.Negocio(negocio_id),
    CONSTRAINT CHK_CategoriaEquipo_tarifah  CHECK (tarifa_hora > 0),
    CONSTRAINT CHK_CategoriaEquipo_tarifad  CHECK (tarifa_dia > 0),
    CONSTRAINT CHK_CategoriaEquipo_deposito CHECK (monto_deposito >= 0)
);
GO

/* ============================================================================
   4. Equipo (depende de CategoriaEquipo)
   ============================================================================ */

CREATE TABLE renta.Equipo (
    equipo_id         INT IDENTITY(1,1) PRIMARY KEY,
    categoria_id      INT NOT NULL,
    codigo_interno    VARCHAR(20) NOT NULL,
    descripcion       VARCHAR(200) NULL,
    estado            VARCHAR(20) NOT NULL DEFAULT 'Disponible',
    notas             VARCHAR(300) NULL,
    fecha_adquisicion DATE NULL,
    CONSTRAINT UQ_Equipo_codigo   UNIQUE (categoria_id, codigo_interno),
    CONSTRAINT FK_Equipo_Categoria FOREIGN KEY (categoria_id) REFERENCES renta.CategoriaEquipo(categoria_id),
    CONSTRAINT CHK_Equipo_estado  CHECK (estado IN ('Disponible','Reservado','Alquilado','Mantenimiento','Dañado','Fuera de servicio'))
);
GO

/* ============================================================================
   5. Reserva (depende de Negocio y Usuario -- cliente y operador)
   ============================================================================ */

CREATE TABLE renta.Reserva (
    reserva_id    INT IDENTITY(1,1) PRIMARY KEY,
    negocio_id    INT NOT NULL,
    cliente_id    INT NOT NULL,
    operador_id   INT NULL,
    tipo_reserva  VARCHAR(20) NOT NULL,
    fecha_reserva DATETIME NOT NULL DEFAULT GETDATE(),
    fecha_inicio  DATETIME NOT NULL,
    fecha_fin     DATETIME NOT NULL,
    estado        VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    monto_final   DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_Reserva_Negocio  FOREIGN KEY (negocio_id) REFERENCES renta.Negocio(negocio_id),
    CONSTRAINT FK_Reserva_Cliente  FOREIGN KEY (cliente_id) REFERENCES renta.Usuario(usuario_id),
    CONSTRAINT FK_Reserva_Operador FOREIGN KEY (operador_id) REFERENCES renta.Usuario(usuario_id),
    CONSTRAINT CHK_Reserva_tipo    CHECK (tipo_reserva IN ('Anticipada','Walk-in')),
    CONSTRAINT CHK_Reserva_estado  CHECK (estado IN ('Pendiente','Confirmada','En curso','Completada','Cancelada')),
    CONSTRAINT CHK_Reserva_monto   CHECK (monto_final >= 0),
    CONSTRAINT CHK_Reserva_fechas  CHECK (fecha_fin >= fecha_inicio)
);
GO

/* ============================================================================
   6. DetalleReserva (depende de Reserva y Equipo) -- entidad debil
   ============================================================================ */

CREATE TABLE renta.DetalleReserva (
    detalle_id              INT IDENTITY(1,1) PRIMARY KEY,
    reserva_id              INT NOT NULL,
    equipo_id               INT NOT NULL,
    tarifa_aplicada         DECIMAL(10,2) NOT NULL,
    fecha_hora_entrega      DATETIME NULL,
    fecha_hora_devolucion   DATETIME NULL,
    estado_equipo_devolucion VARCHAR(20) NULL,
    CONSTRAINT FK_DetalleReserva_Reserva FOREIGN KEY (reserva_id) REFERENCES renta.Reserva(reserva_id),
    CONSTRAINT FK_DetalleReserva_Equipo  FOREIGN KEY (equipo_id) REFERENCES renta.Equipo(equipo_id),
    CONSTRAINT CHK_DetalleReserva_tarifa CHECK (tarifa_aplicada >= 0),
    CONSTRAINT CHK_DetalleReserva_estado CHECK (estado_equipo_devolucion IS NULL OR estado_equipo_devolucion IN ('Bueno','Dañado','Perdido'))
);
GO

/* ============================================================================
   7. Pago (depende de Reserva y MetodoPago)
   ============================================================================ */

CREATE TABLE renta.Pago (
    pago_id        INT IDENTITY(1,1) PRIMARY KEY,
    reserva_id     INT NOT NULL,
    metodo_pago_id INT NOT NULL,
    monto          DECIMAL(10,2) NOT NULL,
    fecha_pago     DATETIME NOT NULL DEFAULT GETDATE(),
    estado         VARCHAR(20) NOT NULL DEFAULT 'Completado',
    CONSTRAINT FK_Pago_Reserva     FOREIGN KEY (reserva_id) REFERENCES renta.Reserva(reserva_id),
    CONSTRAINT FK_Pago_MetodoPago  FOREIGN KEY (metodo_pago_id) REFERENCES renta.MetodoPago(metodo_pago_id),
    CONSTRAINT CHK_Pago_monto      CHECK (monto > 0),
    CONSTRAINT CHK_Pago_estado     CHECK (estado IN ('Completado','Reembolsado'))
);
GO

/* ============================================================================
   8. Deposito (depende de Reserva, relacion 1 a 1)
   ============================================================================ */

CREATE TABLE renta.Deposito (
    deposito_id      INT IDENTITY(1,1) PRIMARY KEY,
    reserva_id       INT NOT NULL,
    monto_cobrado    DECIMAL(10,2) NOT NULL,
    monto_devuelto   DECIMAL(10,2) NULL,
    monto_retencion  DECIMAL(10,2) NULL,
    fecha_devolucion DATETIME NULL,
    CONSTRAINT UQ_Deposito_Reserva  UNIQUE (reserva_id),
    CONSTRAINT FK_Deposito_Reserva  FOREIGN KEY (reserva_id) REFERENCES renta.Reserva(reserva_id),
    CONSTRAINT CHK_Deposito_cobrado CHECK (monto_cobrado >= 0),
    CONSTRAINT CHK_Deposito_cuadre  CHECK (
        monto_devuelto IS NULL
        OR monto_retencion IS NULL
        OR monto_cobrado = monto_devuelto + monto_retencion
    )
);
GO

/* ============================================================================
   9. Mantenimiento (depende de Equipo y Usuario -- operador responsable)
      *** CORREGIDO: operador_id referencia Usuario, no Rol ***
   ============================================================================ */

CREATE TABLE renta.Mantenimiento (
    mantenimiento_id INT IDENTITY(1,1) PRIMARY KEY,
    equipo_id        INT NOT NULL,
    operador_id      INT NULL,
    tipo             VARCHAR(20) NOT NULL,
    descripcion      VARCHAR(300) NULL,
    costo            DECIMAL(10,2) NOT NULL DEFAULT 0,
    fecha_inicio     DATE NOT NULL,
    fecha_fin        DATE NULL,
    CONSTRAINT FK_Mantenimiento_Equipo  FOREIGN KEY (equipo_id) REFERENCES renta.Equipo(equipo_id),
    CONSTRAINT FK_Mantenimiento_Usuario FOREIGN KEY (operador_id) REFERENCES renta.Usuario(usuario_id),
    CONSTRAINT CHK_Mantenimiento_tipo   CHECK (tipo IN ('Preventivo','Correctivo')),
    CONSTRAINT CHK_Mantenimiento_costo  CHECK (costo >= 0)
);
GO

/* ============================================================================
   10. AuditoriaEquipo (depende de Equipo y Usuario) -- poblada por trigger
       *** CORREGIDO: se agrega usuario_id, faltaba en el diagrama relacional ***
   ============================================================================ */

CREATE TABLE renta.AuditoriaEquipo (
    auditoria_id    INT IDENTITY(1,1) PRIMARY KEY,
    equipo_id       INT NOT NULL,
    usuario_id      INT NULL,
    estado_anterior VARCHAR(20) NULL,
    estado_nuevo    VARCHAR(20) NOT NULL,
    fecha_hora      DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_AuditoriaEquipo_Equipo   FOREIGN KEY (equipo_id) REFERENCES renta.Equipo(equipo_id),
    CONSTRAINT FK_AuditoriaEquipo_Usuario  FOREIGN KEY (usuario_id) REFERENCES renta.Usuario(usuario_id)
);
GO
