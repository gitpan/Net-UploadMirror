# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Net-UploadMirror.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

# use Test::More "no_plan";
 use Test::More tests => 32;
BEGIN { use_ok('Net::UploadMirror') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
# this section will test the methods in the baseclass Net::MirrorDir
 my $mirror = Net::UploadMirror->new(
 	localdir		=> "TestA",
 	remotedir	=> "TestD",
 	ftpserver		=> "www.net.de",
 	usr		=> 'e-mail@address.de',
 	pass		=> "xyz", 	
 	);
#-------------------------------------------------
# can we use the methods of the base class
 isa_ok($mirror, "Net::MirrorDir");
 can_ok($mirror, "Connect");
 can_ok($mirror, "Quit");
 can_ok($mirror, "ReadLocalDir");
 can_ok($mirror, "ReadRemoteDir");
 can_ok($mirror, "LocalNotInRemote");
 can_ok($mirror, "RemoteNotInLocal");
 can_ok($mirror, "DESTROY");
 can_ok($mirror, "AUTOLOAD");
 ok($mirror->SetLocaldir("TestB"));
 ok("TestB" eq $mirror->GetLocaldir());
 ok($mirror->AddSubset("test"));
 ok("test" eq $mirror->GetSubset()->[0]);
#-------------------------------------------------
# now we test the Net::UploadMirror methods
 isa_ok($mirror, "Net::UploadMirror");
 can_ok($mirror, "Update");
 can_ok($mirror, "_Init");
 ok($mirror->_Init());
 can_ok($mirror, "StoreFiles");
 can_ok($mirror, "MakeDirs");
 can_ok($mirror, "DeleteFiles");
 can_ok($mirror, "RemoveDirs");

 ok($mirror->SetConnection(1));
 ok($mirror->StoreFiles([]));
 ok($mirror->MakeDirs([]));
 ok($mirror->SetDelete("enable"));
 ok($mirror->DeleteFiles([]));
 ok($mirror->RemoveDirs([]));
 ok($mirror->SetDelete("disabled"));
 ok($mirror->SetConnection(undef));

 can_ok($mirror, "CheckIfModified");
 ok($mirror->CheckIfModified({}));
#-------------------------------------------------








