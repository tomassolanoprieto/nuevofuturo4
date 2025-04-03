/*
  # Actualizar restricción del PIN

  1. Cambios
    - Eliminar la restricción actual del PIN de 4 dígitos
    - Añadir nueva restricción para 6 dígitos
  
  2. Notas
    - La nueva restricción asegura que el PIN tenga exactamente 6 dígitos
    - Se usa una expresión regular para validar el formato
*/

-- Drop the existing constraint
ALTER TABLE employee_profiles
DROP CONSTRAINT IF EXISTS pin_format;

-- Add new constraint for 6 digits
ALTER TABLE employee_profiles
ADD CONSTRAINT pin_format CHECK (pin ~ '^\d{6}$');