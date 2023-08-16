SET NAMES 'utf8mb4';

DROP TABLE IF EXISTS sources;
CREATE TABLE sources (
  source_id INT(11) UNSIGNED NOT NULL auto_increment,
  sourcetype VARCHAR(16) NOT NULL DEFAULT 'personal',
  url VARCHAR(1024) NOT NULL,
  urlhash CHAR(32) NOT NULL,
  status SMALLINT(6) DEFAULT 0,
  found_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_checked DATETIME DEFAULT NULL,
  default_author VARCHAR(128) DEFAULT NULL,
  name VARCHAR(128) DEFAULT NULL,
  PRIMARY KEY (source_id),
  UNIQUE KEY (urlhash),
  KEY (last_checked)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS `links`;
CREATE TABLE `links` (
  `link_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `url` varchar(1024) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `urlhash` char(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` smallint(6) DEFAULT '0',
  `source_id` int(11) unsigned NOT NULL,
  `found_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_checked` datetime DEFAULT NULL,
  `etag` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `filesize` int(10) unsigned DEFAULT NULL,
  `doc_id` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`link_id`),
  KEY `source_id_2` (`source_id`),
  KEY `urlhash` (`urlhash`),
  KEY `last_checked` (`last_checked`),
  KEY `doc_id` (`doc_id`),
  CONSTRAINT `links_ibfk_1` FOREIGN KEY (`source_id`) REFERENCES `sources` (`source_id`) ON DELETE CASCADE,
  CONSTRAINT `links_ibfk_2` FOREIGN KEY (`doc_id`) REFERENCES `docs` (`doc_id`)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS docs;
CREATE TABLE docs (
  doc_id INT(11) UNSIGNED NOT NULL auto_increment,
  status SMALLINT(6) DEFAULT 1,
  doctype VARCHAR(16) NOT NULL,
  url VARCHAR(1024) NOT NULL,
  urlhash CHAR(32) NOT NULL,
  filetype VARCHAR(8) DEFAULT NULL,
  filesize INT(10) UNSIGNED DEFAULT NULL,
  found_date DATETIME DEFAULT NULL,
  earlier_id INT(11) UNSIGNED DEFAULT NULL,
  authors VARCHAR(255) DEFAULT NULL,
  title VARCHAR(255) DEFAULT NULL,
  abstract TEXT DEFAULT NULL,
  numwords MEDIUMINT UNSIGNED DEFAULT NULL,
  numpages SMALLINT(6) UNSIGNED DEFAULT NULL,
  source_id INT(10) UNSIGNED DEFAULT NULL,
  source_url VARCHAR(1024) DEFAULT NULL,
  source_name VARCHAR(255) DEFAULT NULL,
  meta_confidence TINYINT UNSIGNED DEFAULT NULL,
  is_paper TINYINT UNSIGNED DEFAULT NULL,
  is_philosophy TINYINT UNSIGNED DEFAULT NULL,
  hidden TINYINT(1) NOT NULL,
  content MEDIUMTEXT DEFAULT NULL,
  filehash VARCHAR(32) DEFAULT '',
  PRIMARY KEY (doc_id),
  UNIQUE KEY (urlhash),
  KEY (found_date)
  KEY (source_id),
  CONSTRAINT `docs_ibfk_1` FOREIGN KEY (`source_id`) REFERENCES `sources` (`source_id`) ON DELETE SET NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS cats;
CREATE TABLE cats (
  cat_id INT(11) UNSIGNED NOT NULL auto_increment,
  label VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (cat_id),
  UNIQUE KEY (label)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS docs2cats;
CREATE TABLE docs2cats (
  doc2cat_id INT(11) UNSIGNED NOT NULL auto_increment,
  doc_id INT(11) UNSIGNED NOT NULL,
  cat_id INT(11) UNSIGNED NOT NULL,
  strength INT(11) UNSIGNED DEFAULT NULL,
  is_training TINYINT(1) UNSIGNED DEFAULT 0,
  PRIMARY KEY (doc2cat_id),
  KEY (doc_id),
  KEY (cat_id),
  UNIQUE KEY (cat_id, doc_id)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

INSERT INTO cats (label) VALUES ('philosophy');
INSERT INTO cats (label) VALUES ('Metaphysics');
INSERT INTO cats (label) VALUES ('Epistemology');

DROP TABLE IF EXISTS author_names;
CREATE TABLE author_names (
  name_id INT(11) UNSIGNED NOT NULL auto_increment,
  name VARCHAR(64) NOT NULL,
  last_searched DATETIME DEFAULT NULL,
  is_name TINYINT UNSIGNED DEFAULT 1,
  PRIMARY KEY (name_id),
  UNIQUE KEY (name)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS `docs2users`;
CREATE TABLE `docs2users` (
  `doc2user_id` int(11) NOT NULL AUTO_INCREMENT,
  `strength` int(11) DEFAULT NULL,
  `is_training` tinyint(1) NOT NULL,
  `doc_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`doc2user_id`),
  UNIQUE KEY (`doc_id`,`user_id`)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS `journals`;
CREATE TABLE `journals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB CHARACTER SET utf8mb4;

--
