# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Net-UploadMirror.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

# use Test::More "no_plan";
 use Test::More tests => 51;
BEGIN { use_ok('Net::UploadMirror') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
# this section will test the methods in the baseclass Net::MirrorDir
 my $mirror = Net::UploadMirror->new(
 	localdir		=> "TestA",
 	remotedir	=> "TestD",
 	ftpserver		=> "www.net.de",
 	user		=> 'e-mail@address.de',
 	pass		=> "xyz", 	
 	);
#-------------------------------------------------
# can we use the methods of the base class
 isa_ok($mirror, "Net::MirrorDir");
 can_ok($mirror, "Connect");
 can_ok($mirror, "IsConnection");
 can_ok($mirror, "Quit");
 can_ok($mirror, "ReadLocalDir");
 ok($mirror->ReadLocalDir('.'));
 can_ok($mirror, "ReadRemoteDir");
 can_ok($mirror, "LocalNotInRemote");
 ok($mirror->LocalNotInRemote({}, {}));
 can_ok($mirror, "RemoteNotInLocal");
 ok($mirror->RemoteNotInLocal({}, {}));
 can_ok($mirror, "DESTROY");
 can_ok($mirror, "AUTOLOAD");
#-------------------------------------------------
 ok($mirror->Set_Remotedir("TestA"));
 ok("TestA" eq $mirror->get_remotedir());
 ok($mirror->SetLocaldir("TestB"));
 ok("TestB" eq $mirror->GetLocaldir());
#-------------------------------------------------
# test attribute "subset"
 ok($mirror->SetSubset([]));
 ok($mirror->AddSubset("test_1"));
 ok("test_1" eq $mirror->GetSubset()->[0]);
 ok($mirror->AddSubset("test_2"));
 ok("test_2" eq $mirror->GetSubset()->[1]);
 ok($mirror->add_subset("test_3"));
 ok("test_3" eq $mirror->get_subset()->[2]);
 my $count = 0;
 for my $regex (@{$mirror->{_regex_subset}})
 	{
 	for("---test_1---", "---test_2---", "---test_3---")
 		{
 		$count++ if(/$regex/)
 		}
 	}
 ok($count == 3);
#-------------------------------------------------
# test attribute "exclusions"
 ok($mirror->SetExclusions([qr/test_1/]));
 ok($mirror->AddExclusions(qr/test_2/));
 ok($mirror->add_exclusions(qr/test_3/));
 $count = 0;
 for my $regex (@{$mirror->get_regex_exclusions()})
 	{
 	for("xxxtest_1xxx", "xxxtest_2xxx", "xxxtest_3xxx")
 		{
 		$count++ if(/$regex/);
 		}
 	}
 ok($count == 3);
#-------------------------------------------------
# now we test the Net::UploadMirror methods
 isa_ok($mirror, "Net::UploadMirror");
 can_ok($mirror, "Upload");
 can_ok($mirror, "_Init");
 ok($mirror->_Init());
 can_ok($mirror, "StoreFiles");
 ok(!$mirror->StoreFiles([]));
 can_ok($mirror, "MakeDirs");
 ok(!$mirror->MakeDirs([]));
 can_ok($mirror, "DeleteFiles");
 ok(!$mirror->DeleteFiles([]));
 can_ok($mirror, "RemoveDirs");
 ok(!$mirror->RemoveDirs([]));
 can_ok($mirror, "CheckIfModified");
 ok($mirror->CheckIfModified({}));
#-------------------------------------------------
# tests for "filename"
 ok($mirror->GetFileName() eq "lastmodified_local");
 ok($mirror->SetFileName("modtime"));
 ok($mirror->GetFileName() eq "modtime");
 ok(unlink("lastmodified_local"));
 ok(unlink("modtime"));
#-------------------------------------------------
 SKIP:
 	{
	skip("no tests with user prompt\n", 2) if($ENV{AUTOMATED_TESTING});
 	my $oldfh = select(STDERR);
 	$| = 1;
	print("\nWould you like to  test the module with a ftp-server?[y|n]: ");
 	my $response = <STDIN>;
 	skip("no tests with ftp-server\n", 2) if(!($response =~ m/^y/i));
 	print("\nPlease enter the hostname of the ftp-server: ");
 	my $s = <STDIN>;
 	chomp($s);
 	print("\nPlease enter your user name: ");
 	my $u = <STDIN>;
 	chomp($u);
 	print("\nPlease enter your ftp-password: ");
 	my $p = <STDIN>;
 	chomp($p);
	print("\nPlease enter the local-directory: ");
 	my $l = <STDIN>;
 	chomp($l);
 	print("\nPease enter the remote-directory: ");
 	my $r = <STDIN>;
 	chomp($r);
 	ok(my $m = Net::UploadMirror->new(
 		localdir		=> $l,
 		remotedir	=> $r,
 		ftpserver		=> $s,
 		user		=> $u,
 		pass		=> $p,
 		filename		=> "mtimes",
 		timeout		=> 5
 		));
 	ok($m->Upload());
 	select($oldfh);
 	}
#-------------------------------------------------
