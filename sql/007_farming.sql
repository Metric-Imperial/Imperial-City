-- 007_farming.sql — imperial_farming persistent plants.

CREATE TABLE IF NOT EXISTS `imperial_farm_plants` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `crop` VARCHAR(32) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `planted_at` INT UNSIGNED NOT NULL,
  `watered_at` INT UNSIGNED NOT NULL,
  `fertilised` TINYINT(1) NOT NULL DEFAULT 0,
  `health` TINYINT UNSIGNED NOT NULL DEFAULT 100,
  PRIMARY KEY (`id`),
  KEY `idx_farm_citizenid` (`citizenid`),
  KEY `idx_farm_xy` (`x`, `y`),
  KEY `idx_farm_planted` (`planted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('007_farming');
