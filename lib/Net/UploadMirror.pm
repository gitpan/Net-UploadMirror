#*** UploadMirror.pm ***#
# Copyright (C) 2005 - 2008 by Torsten Knorr
# create-soft@tiscali.de
# All rights reserved!
#-------------------------------------------------
 use strict;
#------------------------------------------------
 package Net::UploadMirror::FileName;
 use Storable;
 sub TIESCALAR{ my ($class, $obj) = @_; return(bless(\$obj, $class || ref($class))); }
 sub STORE 
 	{
 	if(-f $_[1])
 		{
 		${$_[0]}->{_last_modified} = retrieve($_[1]);
 		}
 	else
 		{
 		${$_[0]}->{_last_modified} = {};
 		store(${$_[0]}->{_last_modified}, $_[1]);
 		warn("\nno information of the files last modified times\n");
 		}
 	}
 sub FETCH { return(${$_[0]}->{_filename}); }
#-------------------------------------------------
 package Net::UploadMirror;
#-------------------------------------------------
 use Net::MirrorDir;
 use Storable;
 use File::Basename;
 use vars '$AUTOLOAD';
#------------------------------------------------
 @Net::UploadMirror::ISA = qw(Net::MirrorDir);
 $Net::UploadMirror::VERSION = '0.09';
#-------------------------------------------------
 sub _Init
 	{
 	my ($self, %arg) = @_;
	tie($self->{_filename}, "Net::UploadMirror::FileName", $self);
 	$self->{_filename}	= $arg{filename}	|| "lastmodified_local";
 	$self->{_delete}	= $arg{delete}	|| "disabled";
 	return(1);
 	}
#-------------------------------------------------
 sub Update
 	{
 	my ($self) = @_;
 	my ($ref_h_local_files, $ref_h_local_dirs) = $self->ReadLocalDir();
 	if($self->{_debug})
 		{
 		print("local files : $_\n") for(sort keys %{$ref_h_local_files});
 		print("local dirs : $_\n") for(sort keys %{$ref_h_local_dirs});
 		}
 	my $ref_a_modified_local_files = $self->CheckIfModified($ref_h_local_files);
 	if($self->{_debug})
 		{
 		print("modified files : $_\n") for(@{$ref_a_modified_local_files});
 		}
 	return(0) if(!$self->Connect());
	$self->StoreFiles($ref_a_modified_local_files);
 	my ($ref_h_remote_files, $ref_h_remote_dirs) = $self->ReadRemoteDir();
 	if($self->{_debug})
 		{
 		print("remote files : $_\n") for(sort keys %{$ref_h_remote_files});
 		print("remote dirs : $_\n") for(sort keys %{$ref_h_remote_dirs});
 		}
	my $ref_a_new_local_files = $self->LocalNotInRemote(
 		$ref_h_local_files,
		$ref_h_remote_files
		);
 	if($self->{_debug})
 		{
 		print("local files not in remote: $_\n") for(@{$ref_a_new_local_files});
 		}
 	$self->StoreFiles($ref_a_new_local_files);
 	my $ref_a_new_local_dirs = $self->LocalNotInRemote(
 		$ref_h_local_dirs,
 		$ref_h_remote_dirs
 		);
 	if($self->{_debug})
 		{
 		print("local directories not in remote : $_\n") for(@{$ref_a_new_local_dirs});
 		}
 	$self->MakeDirs($ref_a_new_local_dirs);
 	if($self->{_delete} eq "enable")
 		{
 		my $ref_a_deleted_local_files = $self->RemoteNotInLocal(
 			$ref_h_local_files,
 			$ref_h_remote_files
 			);
 		if($self->{_debug})
 			{
 			print("remote files not in local : $_\n") for(@{$ref_a_deleted_local_files});
 			}
  		$self->DeleteFiles($ref_a_deleted_local_files);
 		my $ref_a_deleted_local_dirs = $self->RemoteNotInLocal(
 			$ref_h_local_dirs,
 			$ref_h_remote_dirs);
 		if($self->{_debug})
 			{
 			print("remote directories not in local : $_\n") for(@{$ref_a_deleted_local_dirs});
 			}
 		$self->RemoveDirs($ref_a_deleted_local_dirs);
 		}
 	$self->Quit();
 	return(1);
 	}
#-------------------------------------------------
 sub CheckIfModified
 	{
 	my ($self, $ref_h_local_files) = @_;
 	my @modified_files;
 	for(keys(%{$ref_h_local_files}))
 		{
 		next if((-d $_) || !(-f $_));
 		if(defined($self->{_last_modified}{$_}))
 			{
 			next if($self->{_last_modified}{$_} eq (stat($_))[9]);
 			}
 		 push(@modified_files, $_);
 		}
 	return(\@modified_files);
 	}
#-------------------------------------------------
sub StoreFiles
 	{
 	my ($self, $ref_a_files) = @_;
 	return(0) if(!$self->IsConnection() or !@{$ref_a_files});
 	my ($l_path, $r_path);
 	for(@{$ref_a_files})
 		{
 		if(-f $_)
 			{
 			$r_path = $l_path = $_;
 			$r_path =~ s!$self->{_regex_localdir}!$self->{_remotedir}!;
 			my ($r_name, $r_dir, $r_sufix) = fileparse($r_path);
 			if(!($self->{_connection}->cwd($r_dir)))
 				{
 				$self->{_connection}->cwd();
 				$self->{_connection}->mkdir($r_dir, 1);
 				$self->{_connection}->cwd($r_dir);
 				}
 $self->{_last_modified}{$l_path} = (stat($l_path))[9] if($self->{_connection}->put($l_path, $r_name));
 			$self->{_connection}->cwd();
 			}
 		else
 			{
 			warn("error in StoreFiles() : $_ is not a file\n");
 			}
 		}
 	store($self->{_last_modified}, $self->{_filename});
 	return(1);
 	}
#-------------------------------------------------
 sub MakeDirs
 	{
 	my ($self, $ref_a_dirs) = @_;
 	return(0) if(!$self->IsConnection() or !@{$ref_a_dirs});
 	for my $r_dir (@{$ref_a_dirs})
 		{
 		if(-d $r_dir)
 			{
 			$r_dir =~ s!$self->{_regex_localdir}!$self->{_remotedir}!;
 			next if($self->{_connection}->cwd($r_dir));
 			$self->{_connection}->cwd();
 			$self->{_connection}->mkdir($r_dir, 1) ;
 			}
 		else
 			{
			warn("error in MakeDirs() : $r_dir is not a directory\n");
 			}
 		}
 	return(1);
 	}
#-------------------------------------------------
 sub DeleteFiles
 	{
 	my ($self, $ref_a_files) = @_;
	return(0) if(($self->{_delete} ne "enable") or !$self->IsConnection() or !@{$ref_a_files});
 	for my $l_path (@{$ref_a_files})
 		{
		$self->{_connection}->delete($l_path);
 		$l_path =~ s!$self->{_regex_remotedir}!$self->{_localdir}!;
 		delete($self->{_last_modified}{$l_path}) if(defined($self->{_last_modified}{$l_path}));
 		}
 	store($self->{_last_modified}, $self->{_file_name});
 	return(1);
 	}
#-------------------------------------------------
 sub RemoveDirs
 	{
 	my ($self, $ref_a_dirs) = @_;
	return(0) if(($self->{_delete} ne "enable") or !$self->IsConnection() or !@{$ref_a_dirs});
 	$self->{_connection}->rmdir($_, 1) for(@{$ref_a_dirs});
 	return(1);
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
 my $md = Net::UploadMirror->new(
 	ftpserver		=> "my_ftp.hostname.com",
 	usr		=> "my_ftp_usr_name",
 	pass		=> "my_ftp_password",
 	localdir		=> "home/nameA/homepageA",
 	remotedir	=> "public",
 	debug		=> 1 # 1 for yes, 0 for no
 	timeout		=> 60 # default 30
 	delete		=> "enable" # default "disabled"
 	connection	=> $ftp_object, # default undef
# "exclusions" default empty arrayreferences [ ]
 	exclusions	=> ["private.txt", "Thumbs.db", ".sys", ".log"],
# "subset" default empty arrayreferences [ ]
 	subset		=> [".txt, ".pl", ".html", "htm", ".gif", ".jpg", ".css", ".js", ".png"]
# or substrings in pathnames
#	exclusions	=> ["psw", "forbidden_code"]
#	subset		=> ["name", "my_files"]
# or you can use regular expressions
# 	exclusinos	=> [qr/SYSTEM/i, $regex]
# 	subset		=> {qr/(?i:HOME)(?i:PAGE)?/, $regex]
 	filename	=> "modified_times"
 	);
 $um->Update();

=head1 DESCRIPTION

This module is for mirroring a local directory to a remote location via FTP.
For example websites, documentations or developmentstuff which ones were
worked on locally. It is not developt for mirroring large archivs.
But there are not in principle any limits.

=head1 Constructor and Initialization
=item (object)new(options)
 Net::UploadMirror is a derived class from Net::MirrorDir.
 For detailed information about constructor or options
 read the documentation of Net::MirrorDir.

=head2 methods

=item (1)_Init(%arg)
 This function is called by the constructor.
 You do not need to call this function by yourself.

=item (1|0)Update(void)
 Call this function for mirroring automatically, recommended!!!

=item (ref_hash_modified_files)CheckIfModified(ref_list_local_files)
 Takes a hashreference of local filenames to compare the last modification time,
 which is stored in a file, named by the attribute "filename", while uploading. 
 Returns a reference of a list.

=item (1|0)StoreFiles(ref_array_paths)
 Takes a arrayreference of local-paths to upload the files via FTP.

=item (1|0)MakeDirs(ref_array_paths)
 Takes a arrayreference of directories to make in the remote location.

=item (1|0)DeleteFiles(ref_array_paths)
 Takes a arrayreference of files to delete in the remote location.

=item (1|0)RemoveDirs(ref_array_paths)
 Takes a arrayreference of directories to remove in the remote location.

=head2 optional optiones

=item file_name
 The name of the file in which the last modified times will be stored.
 default = "lastmodified_local"

=item delete
 When directories or files are to be deleted = "enable"
 default = "disabled"
 
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

=head1 REPORTING BUGS

 When reporting bugs/problems please include as much information as possible.

=head1 AUTHOR

 Torsten Knorr, E<lt>create-soft@tiscali.deE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2005 - 2008 by Torsten Knorr

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.9.2 or,
at your option, any later version of Perl 5 you may have available.


=cut


