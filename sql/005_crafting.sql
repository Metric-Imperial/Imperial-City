-- 005_crafting.sql — imperial_crafting persistence.

CREATE TABLE IF NOT EXISTS `imperial_crafting_xp` (
  `citizenid` VARCHAR(50) NOT NULL,
  `category` VARCHAR(48) NOT NULL,
  `xp` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_crafting_unlocks` (
  `citizenid` VARCHAR(50) NOT NULL,
  `recipe_id` VARCHAR(64) NOT NULL,
  `unlocked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `recipe_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('005_crafting');
