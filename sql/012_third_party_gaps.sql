-- 012_third_party_gaps.sql — tables required by third-party resources that ship
-- no .sql file of their own, so there is nothing for a query_database task to
-- point at. Confirmed missing on the first live deploy (27/07/2026).
--
-- npwd_qbx_mail: every query in its server/server.lua targets `player_mails`,
-- but the release zip contains no schema. Columns and types are derived from
-- those queries and match the upstream qb-phone table it was ported from
-- (`mailid` is a 6-digit int from its generateMailId()). Without this table the
-- phone's Mail app throws on open, and qbx_core logs a startup warning because
-- `player_mails` is listed in its characterDataTables.
CREATE TABLE IF NOT EXISTS `player_mails` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `sender` VARCHAR(50) DEFAULT NULL,
  `subject` VARCHAR(50) DEFAULT NULL,
  `message` TEXT DEFAULT NULL,
  `read` TINYINT(4) NOT NULL DEFAULT 0,
  `mailid` INT(11) DEFAULT NULL,
  `date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `button` TEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `mailid` (`mailid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('012_third_party_gaps');
