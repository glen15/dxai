-- Delete daily_records for dummy and test users
DELETE FROM daily_records
WHERE user_id IN (
  SELECT id FROM users
  WHERE device_uuid LIKE 'dummy-%' OR device_uuid LIKE 'test-%'
);

-- Delete dummy and test users
DELETE FROM users
WHERE device_uuid LIKE 'dummy-%' OR device_uuid LIKE 'test-%';
