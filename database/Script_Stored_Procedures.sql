/* ============================================================================
   RentaTica - Stored procedures
============================================================================ */
USE RentaTicaDB;
GO

/* ============================================================================
   Tipo de tabla auxiliar para enviar varios equipos en una sola reserva
   ============================================================================ */

CREATE TYPE renta.EquipoReservaType AS TABLE (
    equipo_id       INT NOT NULL,
    tarifa_aplicada DECIMAL(10,2) NOT NULL
);
GO

/* ============================================================================
   1. AUTENTICACION - Verificamos si un usuario existe con ese correo y contrasena.
   ============================================================================ */

CREATE PROCEDURE renta.usp_Auth_ValidarCredenciales
    @email          VARCHAR(100),
    @password_hash  VARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            u.usuario_id,
            u.nombre_completo,
            u.email,
            r.nombre AS rol,
            u.negocio_id
        FROM renta.Usuario u
        INNER JOIN renta.Rol r ON r.rol_id = u.rol_id
        WHERE u.email = @email
          AND u.password_hash = @password_hash;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   2. NEGOCIO - Creamos un nuevo negocio devolvemos ID
   ============================================================================ */

CREATE PROCEDURE renta.usp_Negocio_Crear
    @nombre         VARCHAR(100),
    @direccion      VARCHAR(200) = NULL,
    @telefono       VARCHAR(20)  = NULL,
    @email_contacto VARCHAR(100),
    @negocio_id     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO renta.Negocio (nombre, direccion, telefono, email_contacto)
        VALUES (@nombre, @direccion, @telefono, @email_contacto);

        SET @negocio_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   3. Busca un negocio por su ID
   ============================================================================ */

CREATE PROCEDURE renta.usp_Negocio_ConsultarPorId
    @negocio_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT negocio_id, nombre, direccion, telefono, email_contacto, fecha_registro, estado
        FROM renta.Negocio
        WHERE negocio_id = @negocio_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   4. USUARIO -  Registra un nuevo usuario con el rol Cliente
   ============================================================================ */

CREATE PROCEDURE renta.usp_Usuario_Registrar
    @nombre_completo     VARCHAR(100),
    @email               VARCHAR(100),
    @password_hash       VARCHAR(256),
    @telefono            VARCHAR(20) = NULL,
    @documento_identidad VARCHAR(30) = NULL,
    @usuario_id          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @rol_cliente_id INT = (SELECT rol_id FROM renta.Rol WHERE nombre = 'Cliente');

        INSERT INTO renta.Usuario (nombre_completo, email, password_hash, telefono, documento_identidad, rol_id, negocio_id)
        VALUES (@nombre_completo, @email, @password_hash, @telefono, @documento_identidad, @rol_cliente_id, NULL);

        SET @usuario_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   5.  Crea un empleado con rol Administrador u Operador
   ============================================================================ */

CREATE PROCEDURE renta.usp_Usuario_CrearEmpleado
    @nombre_completo VARCHAR(100),
    @email           VARCHAR(100),
    @password_hash   VARCHAR(256),
    @telefono        VARCHAR(20) = NULL,
    @rol_nombre      VARCHAR(30),      -- 'Administrador' u 'Operador'
    @negocio_id      INT,
    @usuario_id      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @rol_nombre NOT IN ('Administrador','Operador')
        BEGIN
            RAISERROR('El rol debe ser Administrador u Operador.', 16, 1);
            RETURN;
        END

        DECLARE @rol_id INT = (SELECT rol_id FROM renta.Rol WHERE nombre = @rol_nombre);

        INSERT INTO renta.Usuario (nombre_completo, email, password_hash, telefono, rol_id, negocio_id)
        VALUES (@nombre_completo, @email, @password_hash, @telefono, @rol_id, @negocio_id);

        SET @usuario_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   6. CATEGORIA EQUIPO - Crea una categoría de equipos con sus tarifas
   ============================================================================ */

CREATE PROCEDURE renta.usp_CategoriaEquipo_Crear
    @negocio_id     INT,
    @nombre         VARCHAR(80),
    @descripcion    VARCHAR(300) = NULL,
    @tarifa_hora    DECIMAL(10,2),
    @tarifa_dia     DECIMAL(10,2),
    @monto_deposito DECIMAL(10,2),
    @categoria_id   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO renta.CategoriaEquipo (negocio_id, nombre, descripcion, tarifa_hora, tarifa_dia, monto_deposito)
        VALUES (@negocio_id, @nombre, @descripcion, @tarifa_hora, @tarifa_dia, @monto_deposito);

        SET @categoria_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   7. EQUIPO - Registra un equipo nuevo y lo deja como Disponible
   ============================================================================ */

CREATE PROCEDURE renta.usp_Equipo_Crear
    @categoria_id      INT,
    @codigo_interno    VARCHAR(20),
    @descripcion       VARCHAR(200) = NULL,
    @fecha_adquisicion DATE = NULL,
    @equipo_id         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO renta.Equipo (categoria_id, codigo_interno, descripcion, estado, fecha_adquisicion)
        VALUES (@categoria_id, @codigo_interno, @descripcion, 'Disponible', @fecha_adquisicion);

        SET @equipo_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   8. Cambia el estado de un equipo, por ejemplo de Disponible a Mantenimiento
   ============================================================================ */

CREATE PROCEDURE renta.usp_Equipo_ActualizarEstado
    @equipo_id    INT,
    @nuevo_estado VARCHAR(20),
    @usuario_id   INT = NULL   -- es quien hace el cambio, se usa para la auditoria
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Equipo WHERE equipo_id = @equipo_id)
        BEGIN
            RAISERROR('El equipo indicado no existe.', 16, 1);
            RETURN;
        END

        EXEC sp_set_session_context 'usuario_actual', @usuario_id;

        UPDATE renta.Equipo
        SET estado = @nuevo_estado
        WHERE equipo_id = @equipo_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   9. Busca que equipos están disponibles en un período determinado
   ============================================================================ */

CREATE PROCEDURE renta.usp_Equipo_ConsultarDisponibilidad
    @negocio_id   INT,
    @categoria_id INT = NULL,
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT e.equipo_id, e.codigo_interno, e.descripcion, c.nombre AS categoria, e.estado
        FROM renta.Equipo e
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE c.negocio_id = @negocio_id
          AND (@categoria_id IS NULL OR e.categoria_id = @categoria_id)
          AND e.estado NOT IN ('Dañado','Fuera de servicio')
          AND e.equipo_id NOT IN (
                SELECT dr.equipo_id
                FROM renta.DetalleReserva dr
                INNER JOIN renta.Reserva r ON r.reserva_id = dr.reserva_id
                WHERE r.estado IN ('Pendiente','Confirmada','En curso')
                  AND r.fecha_inicio < @fecha_fin
                  AND r.fecha_fin > @fecha_inicio
          );
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
   10. Muestra todos los equipos de un negocio.
   ============================================================================ */

CREATE PROCEDURE renta.usp_Equipo_Listar
    @negocio_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT e.equipo_id, e.codigo_interno, e.descripcion, e.estado,
               c.nombre AS categoria, c.tarifa_hora, c.tarifa_dia
        FROM renta.Equipo e
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE c.negocio_id = @negocio_id
        ORDER BY c.nombre, e.codigo_interno;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


/* ============================================================================
   11. Busca una reserva y muestra sus datos y los equipos que contiene
   ============================================================================ */

CREATE PROCEDURE renta.usp_Reserva_ConsultarPorId
    @reserva_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT r.reserva_id, r.negocio_id, r.cliente_id, r.operador_id, r.tipo_reserva,
               r.fecha_reserva, r.fecha_inicio, r.fecha_fin, r.estado, r.monto_final
        FROM renta.Reserva r
        WHERE r.reserva_id = @reserva_id;

        SELECT dr.detalle_id, dr.equipo_id, e.codigo_interno, dr.tarifa_aplicada,
               dr.fecha_hora_entrega, dr.fecha_hora_devolucion, dr.estado_equipo_devolucion
        FROM renta.DetalleReserva dr
        INNER JOIN renta.Equipo e ON e.equipo_id = dr.equipo_id
        WHERE dr.reserva_id = @reserva_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ============================================================================
    Prueba #1 - usp_Auth_ValidarCredenciales
   ============================================================================ */
   EXEC renta.usp_Auth_ValidarCredenciales
    @email = 'ana@tamarindosurf.com',
    @password_hash = 'hash123';

/* ============================================================================
Prueba #2 - usp_Negocio_Crear
============================================================================ */
    DECLARE @id INT;

EXEC renta.usp_Negocio_Crear
    @nombre = 'Tamarindo Surf Rentals',
    @direccion = 'Tamarindo, Guanacaste',
    @telefono = '8888-1111',
    @email_contacto = 'info@tamarindosurf.com',
    @negocio_id = @id OUTPUT;

SELECT @id AS negocio_creado;
/* ============================================================================
    Prueba #3 - usp_Negocio_ConsultarPorId
   ============================================================================ */
   EXEC renta.usp_Negocio_ConsultarPorId
    @negocio_id = 1;
/* ============================================================================
    Prueba #4 - usp_Usuario_Registrar
   ============================================================================ */
   DECLARE @id INT;

EXEC renta.usp_Usuario_Registrar
    @nombre_completo = 'Carlos Rodriguez',
    @email = 'carlos@test.com',
    @password_hash = 'hash123',
    @telefono = '8888-2222',
    @documento_identidad = 'CR-123456',
    @usuario_id = @id OUTPUT;

SELECT @id AS cliente_creado;
   /* ============================================================================
    Prueba #5 - usp_Usuario_CrearEmpleado
   ============================================================================ */
   DECLARE @id INT;

EXEC renta.usp_Usuario_CrearEmpleado
    @nombre_completo = 'Ana Lopez',
    @email = 'ana@tamarindosurf.com',
    @password_hash = 'hash123',
    @telefono = '8888-3333',
    @rol_nombre = 'Operador',
    @negocio_id = 1,
    @usuario_id = @id OUTPUT;

SELECT @id AS empleado_creado;
   /* ============================================================================
    Prueba #6 - usp_CategoriaEquipo_Crear
   ============================================================================ */
   DECLARE @id INT;

EXEC renta.usp_CategoriaEquipo_Crear
    @negocio_id = 1,
    @nombre = 'Tabla de Surf',
    @descripcion = 'Tablas para principiantes',
    @tarifa_hora = 15.00,
    @tarifa_dia = 50.00,
    @monto_deposito = 100.00,
    @categoria_id = @id OUTPUT;

SELECT @id AS categoria_creada;
   /* ============================================================================
    Prueba #7 - usp_Equipo_Crear
   ============================================================================ */
   DECLARE @id INT;

EXEC renta.usp_Equipo_Crear
    @categoria_id = 1,
    @codigo_interno = 'SURF-001',
    @descripcion = 'Tabla azul de 7 pies',
    @fecha_adquisicion = '2026-09-01',
    @equipo_id = @id OUTPUT;

SELECT @id AS equipo_creado;
   /* ============================================================================
    Prueba #8 - usp_Equipo_ActualizarEstado
   ============================================================================ */
   EXEC renta.usp_Equipo_ActualizarEstado
    @equipo_id = 1,
    @nuevo_estado = 'Mantenimiento',
    @usuario_id = 2;
   /* ============================================================================
    Prueba #9 - usp_Equipo_ConsultarDisponibilidad
   ============================================================================ */
   EXEC renta.usp_Equipo_ConsultarDisponibilidad
    @negocio_id = 1,
    @categoria_id = NULL,
    @fecha_inicio = '2026-10-10 09:00',
    @fecha_fin = '2026-10-10 17:00';
   /* ============================================================================
    Prueba #10 - usp_Equipo_Listar
   ============================================================================ */
   EXEC renta.usp_Equipo_Listar
    @negocio_id = 1;
   /* ============================================================================
    Prueba #11 - usp_Reserva_ConsultarPorId
   ============================================================================ */
   EXEC renta.usp_Reserva_ConsultarPorId
    @reserva_id = 1;

INSERT INTO renta.Rol (nombre)
VALUES
('Administrador'),
('Operador'),
('Cliente');
    SELECT *
FROM renta.Rol;