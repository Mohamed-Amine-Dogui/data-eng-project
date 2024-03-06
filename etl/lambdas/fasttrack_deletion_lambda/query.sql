

INSERT INTO vwredshift.fasttrack_vwn.contract_staging (
    vehicle_identification_number,
    subscription_vehicle_category,
    product,
    inception_date,
    contract_end_date,
    duration,
    event_timestamp )

VALUES
    ('WVWNTST_Dummy', 'VOLKSWAGEN', 'Leasing', '2018-11-09 22:47:00','2023-12-04 00:00:00', 36,'2023-08-31 00:00:00' ),
    ('WVWNTST_Dummy', 'VOLKSWAGEN', 'Leasing', '2018-11-09 22:47:00','2023-12-04 00:00:00', 36,'2023-08-01 00:00:00' ),
    ('WVWNTST_Dummy', 'VOLKSWAGEN', 'Leasing', '2018-11-09 22:47:00','2023-12-04 00:00:00', 36,'2023-07-01 00:00:00' )
