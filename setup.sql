
--
-- Table structure for table `authors`
--

DROP TABLE IF EXISTS `authors`;
CREATE TABLE `authors` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(128) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `authors2tags`
--

DROP TABLE IF EXISTS `authors2tags`;
CREATE TABLE `authors2tags` (
  `author_id` int(11) NOT NULL,
  `tag_id` int(11) NOT NULL,
  PRIMARY KEY  (`author_id`,`tag_id`),
  KEY `tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `docs`
--

DROP TABLE IF EXISTS `docs`;
CREATE TABLE `docs` (
  `id` int(11) NOT NULL auto_increment,
  `duplicates` int(11) default NULL,
  `page` int(11) default NULL,
  `url` varchar(255) default NULL,
  `found` datetime default NULL,
  `last_checked` datetime default NULL,
  `updated` datetime default NULL,
  `status` smallint(6) default NULL,
  `anchortext` varchar(255) default NULL,
  `filetype` varchar(8) default NULL,
  `filesize` int(10) unsigned default NULL,
  `pages` smallint(5) unsigned default NULL,
  `author` varchar(255) default NULL,
  `title` varchar(255) default NULL,
  `abstract` text,
  `confirmed_by` varchar(16) default NULL,
  `confidence` float default NULL,
  `is_spam` float default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `url` (`url`),
  KEY `found` (`found`),
  KEY `last_checked` (`last_checked`),
  KEY `status` (`status`),
  FULLTEXT KEY `author` (`author`,`title`,`abstract`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `docs2tags`
--

DROP TABLE IF EXISTS `docs2tags`;
CREATE TABLE `docs2tags` (
  `doc_id` int(11) NOT NULL,
  `tag_id` int(11) NOT NULL,
  PRIMARY KEY  (`doc_id`,`tag_id`),
  KEY `doc_id` (`doc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `pages`
--

DROP TABLE IF EXISTS `pages`;
CREATE TABLE `pages` (
  `id` int(11) NOT NULL auto_increment,
  `parent` int(11) default NULL,
  `author` int(11) default NULL,
  `url` varchar(255) default NULL,
  `registered` datetime default NULL,
  `last_checked` datetime default NULL,
  `status` int(11) default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `url` (`url`),
  KEY `author` (`author`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tags`;
CREATE TABLE `tags` (
  `tag_id` int(11) NOT NULL auto_increment,
  `tag_name` varchar(128) NOT NULL,
  PRIMARY KEY  (`tag_id`),
  UNIQUE KEY `tag_name` (`tag_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

