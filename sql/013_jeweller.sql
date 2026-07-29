-- 013_jeweller.sql — imperial_sidejobs: gem cutting orders.
--
-- Cutting is deliberately not instant: a player hands over rough stones and
-- comes back later. That means the order has to outlive both the interaction
-- and the player's session, so it lives in the database rather than in memory.

CREATE TABLE IF NOT EXISTS `imperial_jeweller_orders` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `count` INT UNSIGNED NOT NULL,
  `ready_at` INT UNSIGNED NOT NULL,
  `collected` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_jeweller_citizen` (`citizenid`, `collected`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('013_jeweller');
