package Slim::Plugin::Favorites::OpmlFavorites;

# An opml based favorites handler

# $Id$

use strict;

use base qw(Slim::Plugin::Favorites::Opml);

use File::Spec::Functions qw(:ALL);
use Scalar::Util qw(blessed);

use Slim::Utils::Log;
use Slim::Utils::Strings qw(string);

my $log = logger('favorites');

my $favs; # single instance for all callers

sub new {
	return $favs if $favs;

	my $class  = shift;
	my $client = shift; # ignored for this version as favorites are shared by all clients

	$favs = $class->SUPER::new;

	if (-r $favs->filename) {

		$favs->load($favs->filename);

	} else {

		$favs->_loadOldFavorites;
	}

	return $favs;
}

sub filename {
	my $class = shift;

	my $dir = Slim::Utils::Prefs::get('playlistdir') || Slim::Utils::Prefs::get('cachedir');

	return catdir($dir, "favorites.opml");
}

sub load {
	my $class = shift;

	$class->SUPER::load(@_);
	$class->_urlindex;
}

sub save {
	my $class = shift;

	$class->SUPER::save(@_);
	$class->_urlindex;
}

sub _urlindex {
	my $class = shift;
	my $level = shift;
	my $index = shift || '';

	unless (defined $level) {
		$class->{'urlindex'} = {};
		$level = $class->toplevel;
	}

	my $i = 0;

	for my $entry (@{$level}) {

		if ($entry->{'URL'} || $entry->{'url'}) {
			$class->{'urlindex'}->{ $entry->{'URL'} || $entry->{'url'} } = {
				'text' => $entry->{'text'},
				'ind'  => $index."$i",
			};
		}

		if ($entry->{'outline'}) {
			$class->_urlindex($entry->{'outline'}, $index."$i.");
		}

		$i++;
	}
}

sub _loadOldFavorites {
	my $class = shift;

	my $toplevel = $class->toplevel;

	$log->info("No opml favorites file found - loading old favorites");

	my @urls   = Slim::Utils::Prefs::getArray('favorite_urls');
	my @titles = Slim::Utils::Prefs::getArray('favorite_titles');

	while (@urls) {

		push @$toplevel, {
			'text' => shift @titles,
			'URL'  => shift @urls,
			'type' => 'audio',
		};
	}

	$class->title(string('FAVORITES'));

	$class->save;
}

sub add {
	my $class  = shift;
	my $url    = shift;
	my $title  = shift;

	if (!$url) {
		logWarning("No url passed! Skipping.");
		return undef;
	}

	if (blessed($url) && $url->can('url')) {
		$url = $url->url;
	}

	$url =~ s/\?sessionid.+//i;	# Bug 3362, ignore sessionID's within URLs (Live365)

	$log->info(sprintf("url: %s title: %s", $url, $title));

	# if its already a favorite, don't add it again
	if (my $fav = $class->findUrl($url)) {
		return $fav->{'num'};
	}

	my $entry = {
		'text' => $title,
		'URL'  => $url,
	};

	if ($url !~ /\.opml$/) {
		$entry->{'type'} = 'audio';
	};

	# add it to end of top level
	push @{$class->toplevel}, $entry;

	$class->save;

	return scalar @{$class->toplevel} - 1;
}

sub hasUrl {
	my $class = shift;
	my $url   = shift;

	return (defined $class->{'urlindex'}->{ $url });
}

sub findUrl {
	my $class  = shift;
	my $url    = shift;

	$url =~ s/\?sessionid.+//i;	# Bug 3362, ignore sessionID's within URLs (Live365)

	if ($class->{'urlindex'}->{ $url }) {

		$log->info("Match $url at index ".$class->{'urlindex'}->{ $url }->{'ind'});

		return {
			'url'   => $url,
			'title' => $class->{'urlindex'}->{ $url }->{'text'},
			'index' => $class->{'urlindex'}->{ $url }->{'ind'},
		};
	}

	$log->info("No match for $url");

	return undef;
}

sub deleteUrl {
	my $class  = shift;
	my $url    = shift;

	if (blessed($url) && $url->can('url')) {
		$url = $url->url;
	}

	$url =~ s/\?sessionid.+//i;	# Bug 3362, ignore sessionID's within URLs (Live365)

	if ($class->{'urlindex'}->{ $url }) {

		$class->deleteIndex($class->{'urlindex'}->{ $url }->{'ind'});

	} else {

		$log->warn("Can't delete $url index does not exist");
	}
}

sub deleteIndex {
	my $class  = shift;
	my $index  = shift;

	my ($pos, $i) = $class->level($index, 'contains');

	if (ref @{$pos}[ $i ] eq 'HASH') {

		splice @{$pos}, $i, 1;

		$log->info("Removed entry at index $index");

		$class->save;
	}
}


1;
