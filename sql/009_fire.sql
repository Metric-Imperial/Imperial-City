-- 009_fire.sql — imperial_fire department roster/equipment (incidents are
-- ephemeral, server-memory only; nothing to persist there beyond audit logs).

CREATE TABLE IF NOT EXISTS `imperial_fire_roster` (
  `citizenid` VARCHAR(50) NOT NULL,
  `callsign` VARCHAR(16) NOT NULL DEFAULT '',
  `grade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('009_fire');
