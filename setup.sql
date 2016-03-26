SET NAMES 'utf8';

DROP TABLE IF EXISTS sources;
CREATE TABLE sources (
  source_id INT(11) UNSIGNED NOT NULL auto_increment,
  sourcetype VARCHAR(32) NOT NULL DEFAULT 'personal',
  url VARCHAR(512) NOT NULL,
  urlhash CHAR(32) NOT NULL,
  status SMALLINT(6) DEFAULT 0,
  found_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_checked DATETIME DEFAULT NULL,
  default_author VARCHAR(128) DEFAULT NULL,
  name VARCHAR(128) DEFAULT NULL,
  PRIMARY KEY (source_id),
  UNIQUE KEY (urlhash),
  KEY (last_checked)
) ENGINE=InnoDB CHARACTER SET utf8;

DROP TABLE IF EXISTS links;
CREATE TABLE links (
  link_id INT(11) UNSIGNED NOT NULL auto_increment,
  url VARCHAR(512) NOT NULL,
  urlhash CHAR(32) NOT NULL,
  status SMALLINT(6) DEFAULT 0,
  source_id INT(11) UNSIGNED NOT NULL,
  found_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_checked DATETIME DEFAULT NULL,
  etag VARCHAR(255) DEFAULT NULL,
  filesize INT(10) UNSIGNED DEFAULT NULL,
  doc_id INT(11) DEFAULT NULL,
  PRIMARY KEY (link_id),
  UNIQUE KEY (source_id,urlhash),
  KEY (source_id),
  KEY (urlhash),
  KEY (last_checked)
) ENGINE=InnoDB CHARACTER SET utf8;

DROP TABLE IF EXISTS docs;
CREATE TABLE docs (
  doc_id INT(11) UNSIGNED NOT NULL auto_increment,
  status SMALLINT(6) DEFAULT 1,
  doctype VARCHAR(32) NOT NULL,
  url VARCHAR(512) NOT NULL,
  urlhash CHAR(32) NOT NULL,
  filetype VARCHAR(8) DEFAULT NULL,
  filesize INT(10) UNSIGNED DEFAULT NULL,
  found_date DATETIME DEFAULT NULL,
  earlier_id INT(11) UNSIGNED DEFAULT NULL,
  authors VARCHAR(255) DEFAULT NULL,
  title VARCHAR(255) DEFAULT NULL,
  abstract TEXT DEFAULT NULL,
  numwords SMALLINT(6) UNSIGNED DEFAULT NULL,
  numpages SMALLINT(6) UNSIGNED DEFAULT NULL,
  source_url VARCHAR(512) DEFAULT NULL,
  source_name VARCHAR(255) DEFAULT NULL,
  meta_confidence TINYINT UNSIGNED DEFAULT NULL,
  is_paper TINYINT UNSIGNED DEFAULT NULL,
  is_philosophy TINYINT UNSIGNED DEFAULT NULL,
  content MEDIUMTEXT DEFAULT NULL,
  PRIMARY KEY (doc_id),
  UNIQUE KEY (urlhash),
  KEY (found_date)
) ENGINE=InnoDB CHARACTER SET utf8;

DROP TABLE IF EXISTS cats;
CREATE TABLE cats (
  cat_id INT(11) UNSIGNED NOT NULL auto_increment,
  label VARCHAR(255) DEFAULT NULL,
  is_default TINYINT(1) UNSIGNED DEFAULT 0,
  PRIMARY KEY (cat_id),
  UNIQUE KEY (label),
  KEY (is_default)
) ENGINE=InnoDB CHARACTER SET utf8;

DROP TABLE IF EXISTS docs2cats;
CREATE TABLE docs2cats (
  doc_id INT(11) UNSIGNED NOT NULL,
  cat_id INT(11) UNSIGNED NOT NULL,
  strength FLOAT(4,3) UNSIGNED DEFAULT NULL,
  is_training TINYINT(1) UNSIGNED DEFAULT 0,
  PRIMARY KEY (doc_id, cat_id),
  KEY (doc_id),
  KEY (cat_id)
) ENGINE=InnoDB CHARACTER SET utf8;

INSERT INTO cats (label) VALUES ('philosophy');

INSERT INTO cats (label, is_default) VALUES ('Metaphysics', 1);
INSERT INTO cats (label, is_default) VALUES ('Epistemology', 1);

DROP TABLE IF EXISTS author_names;
CREATE TABLE author_names (
  name_id INT(11) UNSIGNED NOT NULL auto_increment,
  name VARCHAR(64) NOT NULL,
  last_searched DATETIME DEFAULT NULL,
  is_name TINYINT UNSIGNED DEFAULT 1,
  PRIMARY KEY (name_id),
  UNIQUE KEY (name)
) ENGINE=InnoDB CHARACTER SET utf8;

