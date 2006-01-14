#*** UploadMirror.pm ***#
# Copyright (C) 2006 Torsten Knorr
# create-soft@tiscali.de
# All rights reserved!
#------------------------------------------------
package Net::UploadMirror;
#------------------------------------------------
 use strict;
 use warnings;
 use Net::MirrorDir;
 use Storable;
 use File::Basename;
 use vars '$AUTOLOAD';
#------------------------------------------------
 @Net::UploadMirror::ISA = qw(Exporter Net::MirrorDir);
 $Net::UploadMirror::VERSION = '0.04';
#-------------------------------------------------
 sub Update
 	{
 	my ($self) = @_;
 	$self->Connect() if(!(defined($self->{_connection})));
 	my ($ref_h_local_files, $ref_h_local_dirs) = $self->ReadLocalDir();
 	if($self->{_debug})
 		{
 		print("local files : $_\n") for(sort keys %{$ref_h_local_files});
 		print("local dirs : $_\n") for(sort keys %{$ref_h_local_dirs});
 		}
 	my ($ref_h_remote_files, $ref_h_remote_dirs) = $self->ReadRemoteDir();
 	if($self->{_debug})
 		{
 		print("remote files : $_\n") for(sort keys %{$ref_h_remote_files});
 		print("remote dirs : $_\n") for(sort keys %{$ref_h_remote_dirs});
 		}
 	my $ref_a_new_local_files = $self->LocalNotInRemote(
 		$ref_h_local_files, $ref_h_remote_files);
 	if($self->{_debug})
 		{
 		print("new files : $_\n") for(@{$ref_a_new_local_files});
 		}
 	$self->StoreFiles($ref_a_new_local_files) if(@{$ref_a_new_local_files});
 	my $ref_a_new_local_dirs = $self->LocalNotInRemote(
 		$ref_h_local_dirs, $ref_h_remote_dirs);
 	if($self->{_debug})
 		{
 		print("new dirs : $_\n") for(@{$ref_a_new_local_dirs});
 		}
 	$self->MakeDirs($ref_a_new_local_dirs) if(@{$ref_a_new_local_dirs});
 	if($self->{_delete} eq "enable")
 		{
 		my $ref_a_deleted_local_files = $self->RemoteNotInLocal(
 			$ref_h_local_files, $ref_h_remote_files);
 		if($self->{_debug})
 			{
 			print("deleted files : $_\n") for(@{$ref_a_deleted_local_files});
 			}
  		$self->DeleteFiles($ref_a_deleted_local_files) if(@{$ref_a_deleted_local_files});
 		my $ref_a_deleted_local_dirs = $self->RemoteNotInLocal(
 			$ref_h_local_dirs, $ref_h_remote_dirs);
 		if($self->{_debug})
 			{
 			print("deleted dirs : $_\n") for(@{$ref_a_deleted_local_dirs});
 			}
 		$self->RemoveDirs($ref_a_deleted_local_dirs) if(@{$ref_a_deleted_local_dirs});
 		}
 	delete($ref_h_local_files->{$_}) for(@{$ref_a_new_local_files});
 	my $ref_a_modified_local_files = $self->CheckIfModified($ref_h_local_files);
 	if($self->{_debug})
 		{
 		print("modified files : $_\n") for(@{$ref_a_modified_local_files});
 		}
 	$self->StoreFiles($ref_a_modified_local_files) if(@{$ref_a_modified_local_files});
 	$self->Quit();
 	return 1;
 	}
#-------------------------------------------------
 sub CheckIfModified
 	{
 	my ($self, $ref_h_local_files) = @_;
 	my (@modified_files, $ref_h_last_modified);
 	if(-f "lastmodified_local")
 		{
 		$ref_h_last_modified = retrieve("lastmodified_local");
 		}
 	else
 		{
 		warn("no information of the last modified time");
 		return [keys(%{$ref_h_local_files})];
 		}
 	for(keys(%{$ref_h_local_files}))
 		{
 		next if((-d $_) || !(-f $_));
 		if(defined($ref_h_last_modified->{$_}))
 			{
 			if(!($ref_h_last_modified->{$_} eq (stat($_))[9]))
 				{
 				push(@modified_files, $_);
 				}
 			}
 		else
 		 	{
 		 	push(@modified_files, $_);
 		 	}
 		}
 	return \@modified_files;
 	}
#-------------------------------------------------
sub StoreFiles
 	{
 	my ($self, $ref_a_files) = @_;
 	my ($l_path, $r_path, $ref_h_last_modified);
 	return if(!(defined($self->{_connection})));
 	if(-f "lastmodified_local")
 		{
 		$ref_h_last_modified = retrieve("lastmodified_local");
 		}
 	else
 		{
 		$ref_h_last_modified = {};
 		}
 	for(@{$ref_a_files})
 		{
 		if(-f $_)
 			{
 			$r_path = $l_path = $_;
 			$r_path =~ s!^$self->{_localdir}!$self->{_remotedir}!;
 			my ($r_name, $r_dir, $r_sufix) = fileparse($r_path);
 			if(!($self->{_connection}->cwd($r_dir)))
 				{
 				$self->{_connection}->cwd();
 				$self->{_connection}->mkdir($r_dir, 1);
 				$self->{_connection}->cwd($r_dir);
 				}
 $ref_h_last_modified->{$l_path} = (stat($l_path))[9] if($self->{_connection}->put($l_path, $r_name));
 			$self->{_connection}->cwd();
 			}
 		else
 			{
 			warn("error in StoreFiles() : $l_path is not a file\n");
 			}
 		}
 	store($ref_h_last_modified, "lastmodified_local");
 	return 1;
 	}
#-------------------------------------------------
 sub MakeDirs
 	{
 	my ($self, $ref_a_dirs) = @_;
 	my ($l_dir, $r_dir);
 	return if(!(defined($self->{_connection})));
 	for(@{$ref_a_dirs})
 		{
 		if(-d $_)
 			{
 			$l_dir = $r_dir = $_;
 			$r_dir =~ s!^$self->{_localdir}!$self->{_remotedir}!;
 			next if($self->{_connection}->cwd($r_dir));
 			$self->{_connection}->cwd();
 			$self->{_connection}->mkdir($r_dir, 1) ;
 			}
 		else
 			{
			warn("error in MakeDirs() : $l_dir is not a directory\n");
 			}
 		}
 	return 1;
 	}
#-------------------------------------------------
 sub DeleteFiles
 	{
 	my ($self, $ref_a_files) = @_;
 	my ($l_path, $ref_h_last_modified);
 	return if(!($self->{_delete} eq "enable"));
 	return if(!(defined($self->{_connection})));
 	if(-f "lastmodified_local")
 		{ 
 		$ref_h_last_modified = retrieve("lastmodified_local");
 		}
 	else
 		{
 		$ref_h_last_modified = {};
 		}
 	for(@{$ref_a_files})
 		{
 		$l_path = $_; 
 		$l_path =~ s!^$self->{_remotedir}!$self->{_localdir}!;
 		$self->{_connection}->delete($_);
 		delete($ref_h_last_modified->{$l_path}) if(defined($ref_h_last_modified->{$l_path}));
 		}
 	store($ref_h_last_modified, "lastmodified_local");
 	return 1;
 	}
#-------------------------------------------------
 sub RemoveDirs
 	{
 	my ($self, $ref_a_dirs) = @_;
 	return if(!(defined($self->{_connection})));
 	return if(!($self->{_delete} eq "enable"));
 	$self->{_connection}->rmdir($_, 1) for(@{$ref_a_dirs});
 	return 1;
 	}
#------------------------------------------------
1;
#------------------------------------------------
__END__

=head1 NAME

Net::UploadMirror - Perl extension for mirroring a local directory via FTP to the remote location

=head1 SYNOPSIS

  use Net::UploadMirror;
  my $um = Net::UploadMirror->new(
 	ftpserver		=> "my_ftp.hostname.com",
 	usr		=> "my_ftp_usr_name",
 	pass		=> "my_ftp_password",
 	);
 $um->Update();
 
 or more detailed
 my $um = Net::UploadMirror->new(
 	ftpserver		=> "my_ftp.hostname.com",
 	usr		=> "my_ftp_usr_name",
 	pass		=> "my_ftp_password",
 	localdir		=> "home/nameA/homepageA",
 	remotedir	=> "public",
 	debug		=> 1 # 1 for yes, 0 for no
 	timeout		=> 60 # default 30
 	delete		=> "enable" # default "disabled"
 	connection	=> $ftp_object, # default undef
 	exclusions	=> ["private.txt", "Thumbs.db", ".sys", ".log"],
 	);
 $um->SetLocalDir("home/nameB/homepageB");
 print("hostname : ", $um->get_ftpserver(), "\n");
 $um->Update();

=head1 DESCRIPTION

This module is for mirroring a local directory to a remote location via FTP.
For example websites, documentations or developmentstuff which ones were
worked on locally. It is not developt for mirroring large archivs.
But there are not in principle any limits.

=head1 Constructor and Initialization

=item (object) new (options)

=head2 required optines

=item ftpserver
the hostname of the ftp-server

=item usr	
the username for authentification

=item pass
password for authentification

=head2 optional optiones

=item localdir
local directory to upload or update, default '.'

=item remotedir
remote location to store the files, default '/' 

=item debug
set it true for more information about the upload-process, default 1 

=item timeout
the timeout for the ftp-serverconnection

=item delete
if you want locally removed files or directories also removed on the remote 
server set this attribute to "enable", default "disabled"

=item connection
takes a Net::FTP-object you should not use that,
it is produced automatically by the UploadMirror-object

=item exclusions
a reference to a list of strings interpreted as regular-expressios ("regex") 
matching to something in the local pathnames, you do not want to upload, 
default empty list [ ]
It is recommended that the local directory no critical files contains!!!

=item (value) get_option (void)
=item (1)  set_option (value)
The functions are generated by AUTOLOAD for all options.
The syntax is not case-sensitive and the character '_' is optional.

=head2 methods

=item (1) Update (void)
call this function for mirroring automatically, recommended!!!

=item (ref_hash_local_files, ref_hash_local_dirs) ReadLocalDir (void)
Returns two hashreferences first  the local-files, second the local-directorys
found in the directory given by the UploadMirror-object,
uses the attribute "localdir". 
The values are in the keys.

=item (ref_hash_remotefiles, ref_hash_remote_dirs) ReadRemoteDir (void)
Returns two hashreferences first the remote-files, second the remote-directorys
found in the directory given by the UploadMirror-object,
uses the attribute "remotedir". 
The values are in the keys.

=item (1) Connect (void)
Makes the connection to the ftp-server.
Uses the attributes "ftpserver", "usr" and "pass" given by the UpoadMirror-object.

=item (1) Quit (void)
Closes the connection with the ftp-server.

=item (ref_hash_local_paths, ref_hash_remote_paths) LocalNotInRemote (ref_list_new_paths)
Takes two hashreferences, given by the functions ReadLocalDir(); and ReadRemoteDir();
to compare with each other. Returns a reference of a list with files or directorys found in 
the local directory but not in the remote location. Uses the attribute "localdir" and 
"remotedir" given by the UploadMirror-object.

=item (ref_hash_local_paths, ref_hash_remote_paths) RemoteNotInLocal (ref_list_deleted_paths)
Takes two hashreferences, given by the functions ReadLocalDir(); and ReadRemoteDir();
to compare with each other. Returns a reference of a list with files or directorys found in 
the remote location but not in the local directory. Uses of the attribure "localdir" and 
"remotedir" given by the UploadMirror-object.

=item (ref_hash_modified_files) CheckIfModified (ref_list_local_files)
Takes a hashreference of local files to compare the last modification stored in a file
"lastmodified_local" while uploading. Returns a reference of a list.

=item (1) StoreFiles (ref_list_paths)
Takes a listreference of local-paths to upload the files via FTP.

=item (1) MakeDirs (ref_list_paths)
Takes a listreference of directorys to make in the remote location.

=item (1) DeleteFiles (ref_list_paths)
Takes a listreference of files to delete in the remote location.

=item (1) RemoveDirs (ref_list_paths)
Takes a listreference of directories to remove in the remote location.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Net::MirrorDir
Net::DownloadMirror
Tk::Mirror
http://www.planet-interkom.de/t.knorr/index.html

=head1 FILES

Net::MirrorDir
Storable
File::Basename

=head1 BUGS

Maybe you'll find some. Let me know.

=head1 AUTHOR

Torsten Knorr, E<lt>knorrcpan@tiscali.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Torsten Knorr

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.9.2 or,
at your option, any later version of Perl 5 you may have available.


=cut










