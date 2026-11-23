CREATE USER etl_loader WITH PASSWORD = N'K9$mP2#vL8@qR5!xZ';
CREATE USER bi_reader WITH PASSWORD = N'W4@nT7#bY3$mK9!pQ';
GRANT SELECT, INSERT, DELETE ON SCHEMA::stg TO etl_loader;
GRANT EXECUTE ON SCHEMA::ctl TO etl_loader;
GRANT EXECUTE ON SCHEMA::trusted TO etl_loader;
GRANT EXECUTE ON SCHEMA::cur TO etl_loader;
GRANT SELECT ON ctl.lote TO etl_loader;

GRANT SELECT ON SCHEMA::bi TO bi_reader;
DENY SELECT ON SCHEMA::stg TO bi_reader;
DENY SELECT ON SCHEMA::trusted TO bi_reader;
DENY SELECT ON SCHEMA::quar TO bi_reader;
DENY SELECT ON SCHEMA::cur TO bi_reader;