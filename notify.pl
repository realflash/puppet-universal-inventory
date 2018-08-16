#!/usr/bin/perl -w
use strict;
use open qw/:std :utf8/;	# tell perl that stdout, stdin and stderr is in utf8
use Data::Dumper;
use Log::Log4perl qw(:easy);
use LWP::UserAgent;
use HTTP::Request::Common;
use Error qw(:try);
use JSON;
use Config::Any;
use File::Basename;
use Getopt::Long;
use YAML;

my $api = "https://mom.puppet.virtualclarity.com/api/";
my $password = $ENV{'FOREMAN_API_PASSWORD'};
my $username = $ENV{'FOREMAN_API_USERNAME'};

# Init logging
my $home = dirname(Cwd::abs_path($0));
Log::Log4perl->init("$home/notify.log4j");
my $log = Log::Log4perl->get_logger('puppet.notifier');

# Check creds
$log->logdie("No API username specified. Set environment variable \$FOREMAN_API_USERNAME") unless $username;
$log->logdie("No API username specified. Set environment variable \$FOREMAN_API_PASSWORD") unless $password;

# Init config
$log->info("Loading configuration");
$log->debug("Looking in $home");
my $all_cfg = Config::Any->load_stems({stems => ["$home/notify_config"], flatten_to_hash => 1, use_ext => 1});
my @found_files = keys(%$all_cfg);
$log->logdie("No config file notify_config.yml found in my run directory $home") unless scalar(@found_files) > 0;
our $cfg = $all_cfg->{$found_files[0]};

# Now look in the OS mapping for which OSs we should recognise and operate on
my $files = [];
foreach my $os (keys %{$cfg->{'os_mapping'}})
{
	my $file = "$home/".$cfg->{'os_mapping'}->{$os}->{'config_file'}.".yml";
	$cfg->{'os_mapping'}->{$os}->{'config_file_full_path'} = $file;				# save for later
	$log->debug("Looking for $file");
	$log->logdie("File does not exist") unless -e $file;
	push(@$files, "$home/".$cfg->{'os_mapping'}->{$os}->{'config_file'});
}
my $pkg_cfg = Config::Any->load_stems({stems => $files, flatten_to_hash => 1, use_ext => 1});

my $limit_node;
my $limit_os;
my $package_list;
# Process options
unless(GetOptions('n|node=s' => \$limit_node, 'p|package-list' => \$package_list, 'o|os=s' => \$limit_os))
{
	$log->fatal("Bad options");
	&printHelp;
	exit 1;
}
$log->info("Limiting to node $limit_node") if $limit_node;
$log->info("Limiting to OS $limit_os") if $limit_node;

my $ua = LWP::UserAgent->new;
# Do we need to accept a self-signed cert?
$ua->ssl_opts(SSL_ca_file => $cfg->{'ca_cert'}) if $cfg->{'ca_cert'};

# We'll need one of these
our $json = JSON->new->allow_nonref;

# Work time
my $os_map = &loadOSList;

#~ my $response = callURL("get", "$api$hostgroup_query")->decoded_content();
#~ my $groups = $json->decode($response);
#~ my $num_groups = $groups->{'total'};
my ($groups, $num_groups) = getAndDecode("hostgroups");
my $i = 1;
my $delayed_messages = [];
foreach my $group (@$groups)
{
	my ($hosts, $num_hosts) = getAndDecode("hostgroups/".$group->{'id'}."/hosts");
	if($num_hosts < 1)
	{
		$log->info("[$i/$num_groups] Skipping group ".$group->{'id'}." - ".$group->{'name'}.", $num_hosts hosts");
		next;
	}
	$log->info("[$i/$num_groups] Processing group ".$group->{'id'}." - ".$group->{'name'}.", $num_hosts hosts");
	my $j = 1;
	foreach my $host (@$hosts)
	{	# If we are supposed to only be working on one node skip all the others
		if($limit_node)
		{
			next unless $host->{'name'} eq $limit_node;
		}

		my ($facts, $num_facts) = getAndDecode("hosts/".$host->{'id'}."/facts");
		$facts = $facts->{$host->{'name'}};		# actual facts are one level down
		if(! defined($facts->{'inventory'}))
		{
			$log->warn("[$j/$num_hosts] Skipping host ".$host->{'name'}." - no inventory data");
			next;
		}
		$log->debug("[$j/$num_hosts] Processing host ".$host->{'name'}." - ".
				$os_map->{$host->{'operatingsystem_id'}});
				
		# Decide which package list to compare to
		my $os_to_apply;
		foreach my $os (keys %{$cfg->{'os_mapping'}})
		{
			foreach my $mapping_string (@{$cfg->{'os_mapping'}->{$os}->{'mapping_strings'}})
			{
				if($mapping_string eq $os_map->{$host->{'operatingsystem_id'}})
				{
					$os_to_apply = $os;
					last;
				}
			}
		}
		$log->debug("Applying package list '$os_to_apply'");
		# If we are supposed to only be working on one OS skip all the others
		if($limit_os)
		{
			next unless $os_to_apply eq $limit_os;
		}
		
		# This is a JSON string that needs further decoding
		my $inventory = $json->decode($facts->{'inventory'});

		# Now check each package
		my $violations = {};
		foreach my $pkg (@$inventory)
		{	
			next unless $pkg->{'name'};			# If it doesn't have a name it is malformed so we ignore it
			$log->trace("Checking installed package $pkg->{'name'} $pkg->{'installed_version'}");
			my $pkg_list_path = $cfg->{'os_mapping'}->{$os_to_apply}->{'config_file_full_path'};
			if(exists($pkg_cfg->{$pkg_list_path}->{$pkg->{'name'}}))
			{	# A package with that name is defined in the package list
				if(checkPackageVersion($pkg_cfg->{$pkg_list_path}->{$pkg->{'name'}}->{'installed_version'}, $pkg->{'installed_version'}))
				{
					$log->trace("NAME OK VERSION OK");
					delete($violations->{$pkg->{'name'}}); 	# Not a violation after all
				}
				else
				{
					$log->trace("NAME OK VERSION BAD");
					$violations->{$pkg->{'name'}} = $pkg;	# Potentially violating package
				}
			}
			else
			{	# No rule had a matching name. Is there are a wildcard rule?
				if(exists($pkg_cfg->{$pkg_list_path}->{'ANY'}) && $pkg->{'vendor'})
				{
					my $wildcard = $pkg_cfg->{$pkg_list_path}->{'ANY'};
					my $vendor_match = 0;
					foreach my $vendor (@{$wildcard->{'vendor'}})
					{
						if($vendor eq $pkg->{'vendor'})
						{
							$vendor_match = 1;
						}
					}
					if($vendor_match)
					{
						$log->trace("NAME NOT FOUND MATCHED VENDOR WILDCARD");
						delete($violations->{$pkg->{'name'}}); 	# Not a violation after all
						next;
					}
				}
				$log->trace("NAME NOT FOUND");
				$violations->{$pkg->{'name'}} = $pkg;	# Potentially violating package
			}
		}
		
		if(scalar(keys %$violations) > 0)
		{
			# We now have a list of violations for this host.
			# Get rid of version numbers so that the rules are simpler and match better
			foreach my $package (keys %$violations)
			{
				delete($violations->{$package}->{'installed_version'});
				delete($violations->{$package}->{'name'});
				$violations->{$package} = undef if(scalar(keys(%{$violations->{$package}})) < 1);
			}
			my $yaml = Dump([$violations]);
			# Slight tweaks to output styles
			$yaml =~ s/: ~/:/g;
			$yaml =~ s/^- /  /gm;
			if($package_list)
			{	# Instead of alerting, print a list of the violations in the package list format so that it 
				my $output_file = "/tmp/$host->{'name'}.yml";
				open(FH, '>', $output_file) || die "Couldn't open file $output_file";
				print FH $yaml;
				close(FH);
				push(@$delayed_messages, "Violations written to $output_file");
			}
		}
		$j++;			# increment node counter
	}
	$i++;				# increment group counter
}

# Print out any delayed messages
foreach my $msg (@$delayed_messages)
{
	$log->info($msg);
}
$log->info("Done");

sub checkPackageVersion
{
	my $spec = shift;
	my $installed = shift;
	
	if(! defined($spec))
	{
		return 1;
	}
	elsif(ref($spec) eq "")
	{	# Make it an array so both types can be handled the same way
		$spec = [$spec];
	}
	my $version_match = 0;
	my $ban_match = 0;
	foreach my $version (@$spec)
	{
		my $num_matches = ($version =~ s/^!//);
		if($num_matches > 0)
		{	# This is a not version rule
			if($version eq $installed) { $ban_match = 1; }
		}
		else
		{	# This is a normal version rule
			if($version eq $installed) { $version_match = 1; }
		}
	}
	if($ban_match)
	{	# Ban takes precedence
		$log->trace("Version banned");
		return 0;
	}
	elsif($version_match)
	{	# The version is OK
		$log->trace("Version matched");
		return 1;
	}
	else
	{	# No matching version
		$log->trace("Version not matched");
		return 0;
	}
}

sub loadOSList
{
	my ($oss, $num_os) = getAndDecode("operatingsystems");
	my $os_id_map = {};
	foreach my $os (@$oss)
	{
		my $id = $os->{'id'};
		my $name = $os->{'name'};
		$os_id_map->{$id} = $name;
	}
	
	return $os_id_map;
}

sub getAndDecode
{
	my $endpoint = shift;
	
	my $response = callURL("get", "$api${endpoint}?per_page=9999")->decoded_content();
	my $items = $json->decode($response);
	my $num_items = $items->{'total'};
	return ($items->{'results'}, $num_items);
}

sub callURL
{
	my $method = shift;
	my $url = shift;
	my $options = shift;
	my $content = shift;
	
	$log->trace("$method $url");
	$log->logdie("Blank URL supplied") unless $url;
	if($options->{'show_redirects'})
	{
		$log->trace("Showing every redirect");
		$ua->max_redirect(0);			# We want to see the redirects happening, so we'll handle them ourselves. This only retains cookies
											# if $self->ua is a WWW::Mechanize, not an LWP::UserAgent
	}
	my $response = undef;
	my $request = undef;
	if($method =~ /^get$/i)
	{
		$request = HTTP::Request->new('GET', $url);
	}
	elsif($method =~ /^post$/i)
	{
		$request = HTTP::Request->new('POST', $url, undef, $content);
	}
	else
	{
		throw NotImplementedException("I only support GET or POST");
	}
	try
	{
		$request->authorization_basic($username, $password);
		$response = $ua->request($request);
	}
	catch Error with
	{
		if($options->{'log_level'})
		{
			$log->log($options->{'log_level'}, shift);
		}
		else
		{
			$log->logdie(shift);
		}
	};

	$log->trace("Response: ".$response->status_line);
	output_response($response, $options);

	if($options->{'show_redirects'})
	{
		if($response->code =~ /^3/)
		{
			$response = callURL('GET', $response->header('Location'), $options);
		}
	}

	return $response;
}

sub output_response
{
	my $response = shift;
	my $options = shift;
	
	my $response_store_file = '/tmp/file';
	my $response_raw_file = '/tmp/response.html';
	
	if($options->{'store'})
	{
		$log->trace("Storing response in $response_store_file");
		store($response, $response_store_file);
	}
	
	if($options->{'dump_response'})
	{
		$log->trace("Storing decoded response in $response_raw_file");
		open FH, ">$response_raw_file";
		print FH "Response: ".$response->status_line."\n";
		print FH $response->decoded_content();
		close FH;
	}
}

sub printHelp
{
	print STDERR "
./notify.pl [--node <node_name>] [--package-list]
	--node,-n			Limit to working on just this node. By default
						this tool processes every node.
	
	--package-list,-p	Write a YAML file containing the violations that
						you could add to the existing package list so that
						they are no longer violations
";
}
