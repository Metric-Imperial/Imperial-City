-- 011_boosting.sql — imperial_boosting reputation + contract history.

CREATE TABLE IF NOT EXISTS `imperial_boosting_reputation` (
  `citizenid` VARCHAR(50) NOT NULL,
  `reputation` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('011_boosting');
