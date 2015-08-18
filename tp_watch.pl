#!/usr/bin/perl

use JSON;
use Data::Dumper;

my $watching = "31065";
# Mode 1 checks for movement in "buys"
# Mode 2 checks for movement in "sells"
# Mode 0 does both.
# Doesn't do anything right now though.
my $mode = 0;

# encode_json takes a ref scalar like decode_json.
my $statefile = "state.json";
my $log = "watch.txt";

# Load the state file if there's any:
my $prev_listings;
my $state_present = 0;
if (-e $statefile) {
	# Load the state, put everything in one string:
	open (STATE, "<$statefile");
	my $file_contents = do { local $/; <STATE> };
	$prev_listings = decode_json($file_contents);
	$state_present = 1;
	close (STATE);
}

my $listingsd = `wget -q -O - "https://api.guildwars2.com/v2/commerce/listings/$watching"`;
my $listings = decode_json($listingsd);
my @buys = @{ $listings->{'buys'} };
my @sells = @{ $listings->{'sells'} };
my @prev_buys;
my @prev_sells;
if ($state_present) {
	@prev_buys = @{ $prev_listings->{'buys'} };
	@prev_sells = @{ $prev_listings->{'sells'} };
}

my %all_previous_buys;
my %all_previous_sells;
my $top_prev_listing = 0;
# lol I'm drunk
my $lowest_prev_sell_order = 100000;
if ($state_present) {
	foreach my $m ( @prev_buys ) {
		# Let's put everyting in a hash:
		$all_previous_buys{$m->{'unit_price'}} = $m->{'quantity'};
		if ($m->{'unit_price'} > $top_prev_listing) {
			$top_prev_listing = $m->{'unit_price'};
		}
	}
	# In the case of selling orders, the lowest in price comes first, and that's the one
	# we're interrested in.
	foreach my $m ( @prev_sells ) {
		$all_previous_sells{$m->{'unit_price'}} = $m->{'quantity'};
		if ($m->{'unit_price'} < $lowest_prev_sell_order) {
			$lowest_prev_sell_order = $m->{'unit_price'};
		}
	}
}


my %all_buys;
my %all_sells;
my $top_listing = 0;
my $lowest_sell_order = 100000;
my $datestring = localtime;
if ($state_present) {
	open (LOG, ">>$log");
	foreach my $m ( @buys ) {
		$all_buys{$m->{'unit_price'}} = $m->{'quantity'};
		if ($m->{'unit_price'} > $top_listing) {
			$top_listing = $m->{'unit_price'};
		}
		
		if (!$all_previous_buys{$m->{'unit_price'}}) {
			# Found something new in listing.
			# We're not taking orders that get +1 qty etc. in consideration here.
			# Not very relevant for a precursor anyway.
			my $price = $m->{'unit_price'} / 10000.0;
			my $qty = $m->{'quantity'};
			print LOG "[$datestring] New listing in buy orders: $price ; Quantity: $qty\n";
		}
	}

	foreach my $m ( @sells ) {
		$all_sells{$m->{'unit_price'}} = $m->{'quantity'};
		if ($m->{'unit_price'} < $lowest_sell_order) {
			$lowest_sell_order = $m->{'unit_price'};
		}
		
		if (!$all_previous_sells{$m->{'unit_price'}}) {
			# Found something new in listing.
			# We're not taking orders that get +1 qty etc. in consideration here.
			# Not very relevant for a precursor anyway.
			my $price = $m->{'unit_price'} / 10000.0;
			my $qty = $m->{'quantity'};
			print LOG "[$datestring] New listing in sell orders: $price ; Quantity: $qty\n";
		}
	}
	
	# Check the listings that aren't there anymore:
	foreach my $m ( @prev_buys ) {
		if (!$all_buys{$m->{'unit_price'}}) {
			my $price = $m->{'unit_price'} / 10000.0;
			my $qty = $m->{'quantity'};
			print LOG "[$datestring] Previous buy order listing is gone: $price ; Quantity: $qty\n";
		}
	}

	foreach my $m ( @prev_sells ) {
		if (!$all_sells{$m->{'unit_price'}}) {
			my $price = $m->{'unit_price'} / 10000.0;
			my $qty = $m->{'quantity'};
			print LOG "[$datestring] Previous sell order listing is gone: $price ; Quantity: $qty\n";
		}
	}
	
	if ($top_prev_listing != $top_listing) {
		my $biggest_listing;
		if ($top_listing > $top_prev_listing) {
			$biggest_listing = $top_listing / 10000.0;
		} else {
			$biggest_listing = $top_prev_listing / 10000.0;
		}
		print LOG "[$datestring] Top buy order listing changed, new price: $biggest_listing\n";
	}

	if ($lowest_prev_sell_order != $lowest_sell_order) {
		my $lowest_listing;
		if ($lowest_sell_order < $lowest_prev_sell_order) {
			$lowest_listing = $lowest_sell_order / 10000.0;
		} else {
			$lowest_listing = $lowest_prev_sell_order / 10000.0;
		}
		print LOG "[$datestring] Top sell order listing changed, new price: $lowest_listing\n";
	}
	
	close (LOG);
}

# Save the state.
open (STATE, ">$statefile");
print STATE $listingsd;
close (STATE);


#print "Matchup id: $mid ; color: $color\n";


#if (length($msg) > 0) {
  # See if notification has been sent:
#  unless (-e '/root/sent') {
    # Send the message.
#    `/usr/local/bin/sendsms_old 32494410736 "$msg"`;
#    `touch /root/sent`;
#  }
#}

