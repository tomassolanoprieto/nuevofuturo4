/*
  # Añadir usuarios registrados a employee_profiles

  1. Cambios
    - Insertar usuarios registrados en auth.users que no estén en employee_profiles
    - Asignar valores por defecto para campos requeridos
  
  2. Notas
    - Solo se añaden usuarios que no estén ya en employee_profiles
    - Se asignan valores por defecto para cumplir con las restricciones NOT NULL
*/

DO $$
DECLARE
    user_record RECORD;
    v_company_id UUID;
BEGIN
    -- Get the first company_id (assuming there's at least one company)
    SELECT id INTO v_company_id FROM company_profiles LIMIT 1;
    
    -- Loop through users that are not in employee_profiles
    FOR user_record IN 
        SELECT au.id, au.email
        FROM auth.users au
        LEFT JOIN employee_profiles ep ON au.id = ep.id
        WHERE ep.id IS NULL
        AND au.id != v_company_id  -- Exclude the company user
    LOOP
        -- Insert the user into employee_profiles with default values
        INSERT INTO employee_profiles (
            id,
            fiscal_name,
            email,
            phone,
            country,
            timezone,
            company_id,
            is_active,
            document_type,
            document_number,
            work_center,
            pin
        ) VALUES (
            user_record.id,
            COALESCE(user_record.email, 'Usuario ' || user_record.id),
            user_record.email,
            '',  -- default phone
            'España',  -- default country
            'Europe/Madrid',  -- default timezone
            v_company_id,
            true,
            'DNI',  -- default document_type
            '',  -- default document_number
            'Principal',  -- default work_center
            LPAD(floor(random() * 1000000)::text, 6, '0')  -- random 6-digit PIN
        );
    END LOOP;
END $$;