# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Net-UploadMirror.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

# use Test::More "no_plan";
 use Test::More tests => 47;
BEGIN { use_ok('Net::UploadMirror') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
 use Net::UploadMirror;
 my $mirror = Net::UploadMirror->new(
 	localdir		=> "TestA",
 	remotedir	=> "TestA",
 	ftpserver		=> "www.net.de",
 	usr		=> 'e-mail@addresse.de',
 	pass		=> "xyz", 	
 	);
 isa_ok($mirror, "Net::UploadMirror");
 can_ok($mirror, "Connect");
 can_ok($mirror, "Quit");
 can_ok($mirror, "Update");
 can_ok($mirror, "ReadLocalDir");
 ok(my ($ref_local_files, $ref_local_dirs) = $mirror->ReadLocalDir());
 can_ok($mirror, "ReadRemoteDir");
# ok(my $ref_remote_files, $ref_remote_dirs) = $mirror->ReadRemoteDir());
 can_ok($mirror, "CheckIfNew");
 my $ref_test_remote_files =
 	{
	"TestA/TestB/TestC/Dir1/test1.txt" => 1,
 	"TestA/TestB/TestC/Dir2/test2.txt" => 1,
 	#"TestA/TestB/TestC/Dir3/test3.txt" => 1,
 	"TestA/TestB/TestC/Dir4/test4.txt" => 1,
 	"TestA/TestB/TestC/Dir5/test5.txt" => 1,
 	};
 my $ref_test_remote_dirs =
 	{
 	"TestA"			=> 1,
 	"TestA/TestB"		=> 1,
 	"TestA/TestB/TestC"	=> 1,
 	"TestA/TestB/TestC/Dir1"	=> 1,
 	"TestA/TestB/TestC/Dir2"	=> 1,
 	#"TestA/TestB/TestC/Dir3"	=> 1,
 	"TestA/TestB/TestC/Dir4" 	=> 1,
 	"TestA/TestB/TestC/Dir5"	=> 1,
 	};
 ok(my $ref_new_files = $mirror->CheckIfNew($ref_local_files, $ref_test_remote_files));
 ok("TestA/TestB/TestC/Dir3/test3.txt" eq $ref_new_files->[0]);
 ok(my $ref_new_dirs = $mirror->CheckIfNew($ref_local_dirs, $ref_test_remote_dirs));
 ok("TestA/TestB/TestC/Dir3" eq $ref_new_dirs->[0]);
 can_ok($mirror, "CheckIfDeleted");
 $ref_test_remote_files->{"TestA/TestB/TestC/Dir6/test6.txt"} = 1;
 $ref_test_remote_dirs->{"TestA/TestB/TestC/Dir6"} = 1;
 ok(my $ref_deleted_files = $mirror->CheckIfDeleted($ref_local_files, $ref_test_remote_files));
 ok("TestA/TestB/TestC/Dir6/test6.txt" eq $ref_deleted_files->[0]);
 ok(my $ref_deleted_dirs = $mirror->CheckIfDeleted($ref_local_dirs, $ref_test_remote_dirs));
 ok("TestA/TestB/TestC/Dir6" eq $ref_deleted_dirs->[0]);
 can_ok($mirror, "CheckIfModified");
 ok(my $ref_modified_files = $mirror->CheckIfModified($ref_local_files)); 	
 ok($mirror->SetConnection(1));
 can_ok($mirror, "StoreFiles");
 ok($mirror->StoreFiles([])); 
 can_ok($mirror, "MakeDirs");
 ok($mirror->MakeDirs());
 ok($mirror->SetDelete("enable"));
 can_ok($mirror, "DeleteFiles");
 ok($mirror->DeleteFiles([]));
 can_ok($mirror, "DeleteDirs");
 ok($mirror->DeleteDirs([]));
 ok($mirror->SetConnection(undef));
 ok($mirror->SetDelete("disabled"));
 ok($mirror->set_Item());
 ok($mirror->get_Item());
 ok($mirror->GETItem());
 ok($mirror->Get_Item());
 ok($mirror->SET____Remotedir("Homepage"));
 ok($mirror->WrongFunction());
 ok($mirror->SetDebug(1));
 ok($mirror->SetFtpServer("home.perl.de"));
 ok(my $server = $mirror->GetFtpServer());
 ok($server eq "home.perl.de");
 ok(my $delete = $mirror->GetDelete());
 ok($delete eq "disabled");
 ok($mirror->Set_Delete("enable"));
 ok($delete = $mirror->get_delete());
 ok($delete eq "enable");






