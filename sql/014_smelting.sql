-- 014_smelting.sql — imperial_sidejobs: furnace batches.
--
-- Smelting is a batch that takes real time: ore and coal go in, metal comes
-- out later. The order therefore outlives the interaction and the session, so
-- it is persisted rather than held in memory.
--
-- Keyed by (citizenid, site): one batch per player per furnace, so a public
-- furnace can serve several people at once without anyone queueing up loads.

CREATE TABLE IF NOT EXISTS `imperial_smelt_orders` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `site` INT UNSIGNED NOT NULL,
  `output` VARCHAR(64) NOT NULL,
  `count` INT UNSIGNED NOT NULL,
  `ready_at` INT UNSIGNED NOT NULL,
  `collected` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_smelt_citizen` (`citizenid`, `site`, `collected`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('014_smelting');
