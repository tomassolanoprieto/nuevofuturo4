-- Create policy for supervisors to view employee data
CREATE POLICY "supervisor_employee_access"
  ON employee_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM supervisor_profiles sp
      WHERE sp.id = auth.uid()
      AND sp.company_id = employee_profiles.company_id
      AND sp.is_active = true
      AND (
        -- Centro: acceso a empleados de sus centros asignados
        (sp.supervisor_type = 'center' AND employee_profiles.work_centers && sp.work_centers) OR
        -- Delegación: acceso a empleados de sus delegaciones asignadas
        (sp.supervisor_type = 'delegation' AND employee_profiles.delegation = ANY(sp.delegations))
      )
    )
  );

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_employee_profiles_work_centers 
ON employee_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_employee_profiles_delegation 
ON employee_profiles(delegation);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_work_centers 
ON supervisor_profiles USING gin(work_centers);

CREATE INDEX IF NOT EXISTS idx_supervisor_profiles_delegations 
ON supervisor_profiles USING gin(delegations);