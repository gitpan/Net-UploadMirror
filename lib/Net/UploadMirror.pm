package Net::UploadMirror;

use 5.009002;
use strict;
use warnings;
use Net::FTP;
use Storable;
use File::Basename;
use vars '$AUTOLOAD';

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Net::UploadMirror ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';


# Preloaded methods go here.
#-------------------------------------------------
 my (
 	$read_local_dir,
 	$read_remote_dir,
 	$ftp,
 	);
#-------------------------------------------------
 sub new
 	{
 	my ($class, %arg) = @_;
 	my $self =
 		{
 		_localdir		=> $arg{localdir}		|| '.',
 		_remotedir	=> $arg{remotedir}	|| '/',
 		_ftpserver	=> $arg{ftpserver}		|| warn("missing ftpserver"),
 		_usr		=> $arg{usr}		|| warn("missing username"),
 		_pass		=> $arg{pass}		|| warn("missing password"),
 		_debug		=> $arg{debug}		|| 1,
 		_timeout		=> $arg{timeout}		|| 30,
 		_delete		=> $arg{delete}		|| "disabled",
 		_connection	=> $arg{connection}	|| undef,
 		_exclusions	=> $arg{exclusions}	|| [],
 		};
 	bless($self, $class || ref($class));
 	return $self;
 	}
#-------------------------------------------------
 sub Connect
 	{
 	my ($self) = @_;
 	 $self->{_connection} = Net::FTP->new(
 		$self->{_ftpserver},
 		Debug	=> $self->{_debug},
 		Timeout	=> $self->{_timeout},
 		) or warn("Cannot connect to $self->{_ftpserver} : $@\n");
 	if($self->{_connection}->login($self->{_usr}, $self->{_pass}))
 		{
 		 $self->{_connection}->binary();
 		}
 	else
 		{
 		$self->{_connection}->quit();
 		$self->{_connection} = undef;
 		}
 	return 1;
 	}
#-------------------------------------------------
 sub Quit
 	{
 	my ($self) = @_;
 	$self->{_connection}->quit();
 	$self->{_connection} = undef;
 	return 1;
 	}
#-------------------------------------------------
 sub Update
 	{
 	my ($self) = @_;
 	$self->Connect() if(!($self->{_connection}));
 	my ($ref_local_files, $ref_local_dirs) = $self->ReadLocalDir();
 	if($self->{_debug})
 		{
 		print("local files : $_\n") for(sort keys %{$ref_local_files});
 		print("local dirs : $_\n") for(sort keys %{$ref_local_dirs});
 		}
 	my ($ref_remote_files, $ref_remote_dirs) = $self->ReadRemoteDir();
 	if($self->{_debug})
 		{
 		print("remote files : $_\n") for(sort keys %{$ref_remote_files});
 		print("remote dirs : $_\n") for(sort keys %{$ref_remote_dirs});
 		}
 	my $ref_new_files = $self->CheckIfNew($ref_local_files, $ref_remote_files);
 	if($self->{_debug})
 		{
 		print("new files : $_\n") for(@{$ref_new_files});
 		}
 	$self->StoreFiles($ref_new_files) if(@{$ref_new_files});
 	my $ref_new_dirs = $self->CheckIfNew($ref_local_dirs, $ref_remote_dirs);
 	if($self->{_debug})
 		{
 		print("new dirs : $_\n") for(@{$ref_new_dirs});
 		}
 	$self->MakeDirs($ref_new_dirs) if(@{$ref_new_dirs});
 	if($self->{_delete} eq "enable")
 		{
 		my $ref_deleted_files = $self->CheckIfDeleted($ref_local_files, $ref_remote_files);
 		if($self->{_debug})
 			{
 			print("deleted files : $_\n") for(@{$ref_deleted_files});
 			}
  		$self->DeleteFiles($ref_deleted_files) if(@{$ref_deleted_files});
 		my $ref_deleted_dirs = $self->CheckIfDeleted($ref_local_dirs, $ref_remote_dirs);
 		if($self->{_debug})
 			{
 			print("deleted dirs : $_\n") for(@{$ref_deleted_dirs});
 			}
 		$self->DeleteDirs($ref_deleted_dirs) if(@{$ref_deleted_dirs});
 		}
 	delete($ref_local_files->{$_}) for(@{$ref_new_files});
 	my $ref_modified_files = $self->CheckIfModified($ref_local_files);
 	if($self->{_debug})
 		{
 		print("modified files : $_\n") for(@{$ref_modified_files});
 		}
 	$self->StoreFiles($ref_modified_files) if(@{$ref_modified_files});
 	$self->Quit();
 	return 1;
 	}
#------------------------------------------------- 	
 sub ReadLocalDir
 	{ 
 	my ($self) = @_;
 	my %local_files = ();
 	my %local_dirs = ();
 	$read_local_dir = sub
 		{
 		my $path = shift;
 		if(-f $path)
 			{
 			$local_files{$path} = 1;
 			return;
 			}
 		if(-d $path)
 			{
 			$local_dirs{$path} = 1;
 			opendir(PATH, $path) or  die("cannot opendir $path : $!\n");
 			my @files = readdir(PATH);
 			closedir(PATH);
 			FILE: for my $file (@files)
 				{
 				next if(($file eq ".") or ($file eq ".."));
 				for(@{$self->{_exclusions}})
 					{
 					next FILE if($file =~ m/$_/);
 					}
 				$read_local_dir->("$path/$file");
 				}
 			return;
 			}
 		warn("$path is neither a file nor a directory\n");
 		};
 	$read_local_dir->($self->{_localdir});
 	return(\%local_files, \%local_dirs);
 	}
#-------------------------------------------------
 sub ReadRemoteDir
 	{
 	my ($self) = @_;
 	my %remote_files = ();
 	my %remote_dirs = ();
 	return if(!(defined($self->{_connection})));
 	$ftp = $self->{_connection};
 	$read_remote_dir = sub 
 		{
 		my $path = shift;
 		if(defined($ftp->size($path)))
 			{
 			$remote_files{$path} = 1;
 			return;
 			}
 		if($ftp->cwd($path))
 			{
 			$ftp->cwd();
 			$remote_dirs{$path} = 1;
 			my @files = $ftp->ls($path);
 			$read_remote_dir->("$path/$_") for(@files);
 			return;
 			}
 		warn("$path is neither a file nor a directory\n");
 		};
 	$read_remote_dir->($self->{_remotedir});
 	return(\%remote_files, \%remote_dirs);
 	}
#-------------------------------------------------
 sub CheckIfNew
 	{
 	my ($self, $ref_local_paths, $ref_remote_paths) = @_;
 	my @new_files = ();
 	my $r_path;
 	for(keys(%{$ref_local_paths}))
 		{
 		$r_path = $_;
 		$r_path =~ s!^$self->{_localdir}!$self->{_remotedir}!;
 		push(@new_files, $_) if(!(defined($ref_remote_paths->{$r_path})));
 		}
 	return \@new_files;
 	}
#-------------------------------------------------
 sub CheckIfDeleted
 	{
 	my ($self, $ref_local_paths, $ref_remote_paths) = @_;
 	my @deleted_files = ();
 	my $l_path;
 	for(keys(%{$ref_remote_paths}))
 		{
 		$l_path = $_;
 		$l_path =~ s!^$self->{_remotedir}!$self->{_localdir}!;
 		push(@deleted_files, $_) if(!(defined($ref_local_paths->{$l_path})));
 		}
 	return \@deleted_files;
 	}
#-------------------------------------------------
 sub CheckIfModified
 	{
 	my ($self, $ref_local_files) = @_;
 	my (@modified_files, $ref_last_modified);
 	if(-f "lastmodified")
 		{
 		$ref_last_modified = retrieve("lastmodified");
 		}
 	else
 		{
 		warn("no information of the last modified time");
 		return [keys(%{$ref_local_files})];
 		}
 	for(keys(%{$ref_local_files}))
 		{
 		next if((-d $_) || !(-f $_));
 		if(!($ref_last_modified->{$_} eq (stat($_))[9]) || 
 			!(defined($ref_last_modified->{$_})))
 			{
 			push(@modified_files, $_);
 			}
 		}
 	return \@modified_files;
 	}
#-------------------------------------------------
sub StoreFiles
 	{
 	my ($self, $ref_files) = @_;
 	my ($l_path, $r_path, $ref_last_modified);
 	return if(!(defined($self->{_connection})));
 	if(-f "lastmodified")
 		{
 		$ref_last_modified = retrieve("lastmodified");
 		}
 	else
 		{
 		$ref_last_modified = {};
 		}
 	for(@{$ref_files})
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
 $ref_last_modified->{$l_path} = (stat($l_path))[9] if($self->{_connection}->put($l_path, $r_name));
 			$ftp->cwd();
 			}
 		else
 			{
 			warn("error in StoreFiles() : $l_path is not a file\n");
 			}
 		}
 	store($ref_last_modified, "lastmodified");
 	return 1;
 	}
#-------------------------------------------------
 sub MakeDirs
 	{
 	my ($self, $ref_dirs) = @_;
 	my ($l_dir, $r_dir);
 	return if(!(defined($self->{_connection})));
 	for(@{$ref_dirs})
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
 	my ($self, $ref_files) = @_;
 	my ($l_path, $ref_last_modified);
 	return if(!($self->{_delete} eq "enable"));
 	return if(!(defined($self->{_connection})));
 	if(-f "lastmodified")
 		{ 
 		$ref_last_modified = retrieve("lastmodified");
 		}
 	else
 		{
 		$ref_last_modified = {};
 		}
 	for(@{$ref_files})
 		{
 		$l_path = $_; 
 		$l_path =~ s!^$self->{_remotedir}!$self->{_localdir}!;
 		$self->{_connection}->delete($_);
 		delete($ref_last_modified->{$l_path}) if(defined($ref_last_modified->{$l_path}));
 		}
 	store($ref_last_modified, "lastmodified");
 	return 1;
 	}
#-------------------------------------------------
 sub DeleteDirs
 	{
 	my ($self, $ref_dirs) = @_;
 	return if(!(defined($self->{_connection})));
 	return if(!($self->{_delete} eq "enable"));
 	$self->{_connection}->rmdir($_, 1) for(@{$ref_dirs});
 	return 1;
 	}
#-------------------------------------------------
 sub AUTOLOAD
 	{
 	no strict "refs";
 	my ($self, $value) = @_;
 	if($AUTOLOAD =~ m/(?:\w|:)*::(?i:get)_*(\w+)/)
 		{
 		my $attr = lc($1);
 		$attr = '_' . $attr;
 		if(exists($self->{$attr}))
 			{
 			*{$AUTOLOAD} = sub
 				{
 				return $self->{$attr};
 				};
 			return $self->{$attr};
 			}
 		else
 			{
 			warn("NO such attriute : $attr\n");
 			}
 		}
 	elsif($AUTOLOAD =~ m/(?:\w|:)*::(?i:set)_*(\w+)/) 
 		{
 		my $attr = lc($1);
 		$attr = '_' . $attr;
 		if(exists($self->{$attr}))
 			{
 			*{$AUTOLOAD} = sub
 				{
 				$self->{$attr} = $value;
 				};
 			$self->{$attr} = $value;
 			return 1;
 			}
 		else
 			{
 			warn("NO such attribute : $attr\n");
 			}
 		}
 	else
 		{
 		warn("no such method : $AUTOLOAD\n");
 		}
 	return 1;
 	}
#-------------------------------------------------
 sub DESTROY
 	{
 	my ($self) = @_;
 	if($self->{_debug})
 		{
 		my $class = ref($self);
 		print("$class object destroyed\n");
 		} 
 	}
#-------------------------------------------------
1;
__END__

=head1 NAME

Net::UploadMirror - Perl extension for mirroring local directory via FTP to the remote location

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

=head1 Constructor and initialization

=item new (options)

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
for more information about the upload-process, default 1 

=item timeout
the timeout for the ftp-serverconnection

=item delete
if you want locally removed files also removed from the remote location set this
attribute to "enable", default "disabled"

=item connection
takes a Net::FTP-object you should not use that,
it is produced automatically by the UploadMirror-object

=item exclusions
a reference to a list of strings interpreted as regular-expressios ("regex") 
matching to something in the pathnames, you do not want to upload, default empty list [ ]
It is recommended that the directory not critical files contains!!!

=item (value) get_option (void)
=item (1)  set_option (value)
The functions are generated by AUTOLOAD for all options.
The syntax is not case-sensitive and the character '_' is optional.

=head2 methods

=item (1) Update (void)
call this function for mirroring automatically, recommended!!!

=item (ref_hash_local_files, ref_hash_local_dirs) ReadLocalDir (void)
Returns two hashreferences first  the local-files, second the local-directorys
found in the directory given by the UploadMirror-object. 
The values are in the keys.
Uses the attribute "localdir" given by the UploadMirrr-object.

=item (ref_hash_remotefiles, ref_hash_remote_dirs) ReadRemoteDir (void)
Returns two hashreferences first the remote-files, second the remote-directorys
found in the directory given by the UploadMirror-object. 
The values are in the keys.
Uses the attribute "remotedir" given by the UploadMirro-object.

=item (1) Connect (void)
Makes the connection to the ftp-server.
Uses the attributes "ftpserver", "usr" and "pass" given by the UpoadMirror-object.

=item (1) Quit (void)
Closes the connection with the ftp-server.

=item (ref_hash_local_paths, ref_hash_remote_paths) CheckIfNew (ref_list_new_paths)
Takes two hashreferences, given by the functions ReadLocalDir(); and ReadRemoteDir();
to compare with each other. Returns a reference of a list with files or directorys found in 
the local directory but not in the remote location. Uses the attribute "localdir" and "remotedir"
given by the UploadMirror-object.

=item (ref_hash_local_paths, ref_hash_remote_paths) CheckIfDeleted (ref_list_deleted_paths)
Takes two hashreferences, given by the functions ReadLocalDir(); and ReadRemoteDir();
to compare with each other. Returns a reference of a list with files or directorys found in 
the remote location but not in the local directory. Uses the attribure "localdir" and "remotedir"
given by the UploadMirror-object.

=item (ref_hash_modified_files) CheckIfModified (ref_list_local_files)
Takes a hashreference of local files to compare the last modification stored in a file
"lastmodified" while uploading. Returns a reference of a list.

=item (1) StoreFiles (ref_list_paths)
Takes a listreference of local-paths to upload the files via FTP.

=item (1) MakeDirs (ref_list_paths)
Takes a listreference of directorys to make in the remote location.

=item (1) DeleteFiles (ref_list_paths)
Takes a listreference of files to delete in the remote location.

=item (1) DeleteDirs (ref_list_paths)
Takes a listreference of directories to remove in the remote location.

=head2 EXPORT

None by default.

=head1 SEE ALSO

http://www.planet-interkom.de/t.knorr/index.html

=head1 FILES

Net::FTP
Storable
File::Basename
They should be standard.

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










