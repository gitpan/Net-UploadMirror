#*** UploadMirror.pm ***#
# Copyright (C) 2005 - 2008 by Torsten Knorr
# create-soft@tiscali.de
# All rights reserved!
#-------------------------------------------------
 use strict;
#------------------------------------------------
 package Net::UploadMirror::FileName;
 use Storable;
 sub TIESCALAR{ my ($class, $obj) = @_; return bless(\$obj, $class || ref($class)); }
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
 sub FETCH { return ${$_[0]}->{_filename}; }
#-------------------------------------------------
 package Net::UploadMirror;
#-------------------------------------------------
 use Net::MirrorDir 0.19;
 use Storable;
 use vars '$AUTOLOAD';
#------------------------------------------------
 @Net::UploadMirror::ISA = qw(Net::MirrorDir);
 $Net::UploadMirror::VERSION = '0.13';
#-------------------------------------------------
 sub _Init
 	{
 	my ($self, %arg) = @_;
	tie($self->{_filename}, 'Net::UploadMirror::FileName', $self);
 	$self->{_filename}	= $arg{filename}	|| 'lastmodified_local';
 	$self->{_delete}	= $arg{delete}	|| 'disabled';
 	return 1;
 	}
#-------------------------------------------------
 sub Upload
 	{
 	my ($self) = @_;
 	return 0 unless($self->Connect());
 	my ($rh_lf, $rh_ld) = $self->ReadLocalDir();
 	if($self->{_debug})
 		{
 		print("local files : $_\n") for(sort keys %$rh_lf);
 		print("local dirs : $_\n") for(sort keys %$rh_ld);
 		}
 	my ($rh_rf, $rh_rd) = $self->ReadRemoteDir();
 	if($self->{_debug})
 		{
 		print("remote files : $_\n") for(sort keys %$rh_rf);
 		print("remote dirs : $_\n") for(sort keys %$rh_rd);
 		}
 	my $ra_ldnir = $self->LocalNotInRemote($rh_ld, $rh_rd);
 	if($self->{_debug})
 		{
 		print("local directories not in remote : $_\n") for(@$ra_ldnir);
 		}
 	$self->MakeDirs($ra_ldnir);
 	my $ra_lfnir = $self->LocalNotInRemote($rh_lf, $rh_rf);
 	if($self->{_debug})
 		{
 		print("local files not in remote: $_\n") for(@$ra_lfnir);
 		}
 	$self->StoreFiles($ra_lfnir);
 	if($self->{_delete} eq 'enable')
 		{
 		my $ra_rfnil = $self->RemoteNotInLocal($rh_lf, $rh_rf);
 		if($self->{_debug})
 			{
 			print("remote files not in local : $_\n") for(@$ra_rfnil);
 			}
  		$self->DeleteFiles($ra_rfnil);
 		my $ra_rdnil = $self->RemoteNotInLocal($rh_ld, $rh_rd);
 		if($self->{_debug})
 			{
 			print("remote directories not in local : $_\n") for(@$ra_rdnil);
 			}
 		$self->RemoveDirs($ra_rdnil);
 		}
 	delete(@{$rh_lf}{@$ra_lfnir});
 	my $ra_mlf = $self->CheckIfModified($rh_lf);
 	if($self->{_debug})
 		{
 		print("modified files : $_\n") for(@$ra_mlf);
 		}
	$self->StoreFiles($ra_mlf);
 	$self->Quit();
 	return 1;
 	}
#-------------------------------------------------
 sub CheckIfModified
 	{
 	my ($self, $rh_lf) = @_;
 	my @mf;
 	my $changed = undef;
 	for my $lf (keys(%$rh_lf))
 		{
 		next unless(-f $lf);
 		if(defined($self->{_last_modified}{$lf}))
 			{
 			next if($self->{_last_modified}{$lf} eq (stat($lf))[9]);
 			}
 		else
 			{
 			$self->{_last_modified}{$lf} = (stat($lf))[9];
 			$changed++;
 			}
 		push(@mf, $lf);
 		}
 	store($self->{_last_modified}, $self->{_filename}) if($changed);
 	return \@mf;
 	}
#-------------------------------------------------
 sub UpdateLastModified
 	{
 	my ($self, $ra_lf) = @_;
 	for(@$ra_lf)
 		{
 		next unless(-e $_);
 		$self->{_last_modified}{$_} = (stat($_))[9];
 		}
 	store($self->{_last_modified}, $self->{_filename});
 	return 1;
 	}
#-------------------------------------------------
 sub StoreFiles
 	{
 	my ($self, $ra_lf) = @_;
 	return 0 unless(@$ra_lf && $self->IsConnection());
 	my $rf;
 	for my $lf (@$ra_lf)
 		{
 		if(-f $lf)
 			{
 			$rf = $lf;
 			$rf =~ s!$self->{_regex_localdir}!$self->{_remotedir}!;
 $self->{_last_modified}{$lf} = (stat($lf))[9] if($self->{_connection}->put($lf, $rf));
 			}
 		else
 			{
 			warn("error in StoreFiles() : $lf is not a local file\n");
 			}
 		}
 	store($self->{_last_modified}, $self->{_filename});
 	return 1;
 	}	
#-------------------------------------------------
 sub MakeDirs
 	{
 	my ($self, $ra_ld) = @_;
 	return 0 unless(@$ra_ld && $self->IsConnection());
 	my $rd;
 	for my $ld (@$ra_ld)
 		{
 		$rd = $ld;
 		if(-d $ld)
 			{
 			$rd =~ s!$self->{_regex_localdir}!$self->{_remotedir}!;
 			$self->{_connection}->mkdir($rd, 1) ;
 			}
 		else
 			{
			warn("error in MakeDirs() : $rd is not a local directory\n");
 			}
 		}
 	return 1;
 	}
#-------------------------------------------------
 sub DeleteFiles
 	{
 	my ($self, $ra_rf) = @_;
	return 0 unless(
 		@$ra_rf
 		&& ($self->{_delete} eq 'enable')
 		&& $self->IsConnection()
 		);
	my $lf;
 	for my $rf (@$ra_rf)
 		{
		$lf = $rf;
		$self->{_connection}->delete($rf);
 		$lf =~ s!$self->{_regex_remotedir}!$self->{_localdir}!;
 		delete($self->{_last_modified}{$lf}) if(defined($self->{_last_modified}{$lf}));
 		}
 	store($self->{_last_modified}, $self->{_filename});
 	return 1;
 	}
#-------------------------------------------------
 sub RemoveDirs
 	{
 	my ($self, $ra_rd) = @_;
	return 0 unless(
 		@$ra_rd
 		&& ($self->{_delete} eq 'enable')
 		&& $self->IsConnection()
 		);
 	$self->{_connection}->rmdir($_, 1) for(@$ra_rd);
 	return 1;
 	}
#-------------------------------------------------
sub CleanUp
 	{
 	my ($self, $ra_exists) = @_;
 	my %h_temp = ();
 	for my $key (@$ra_exists)
 		{
		if(
 			defined($self->{_last_modified}{$key})
 			&&
 			($self->{_last_modified}{$key} =~ m/^\d+$/)
 			)
 			{
 			$h_temp{$key} = delete($self->{_last_modified}{$key});
 			}
 		}
 	if($self->{_debug})
 	 	{
 		print(
 			"key: $_	value: "
 			. (defined($self->{_last_modified}{$_}) ? $self->{_last_modified}{$_} : 'undef')
 			. " removed\n") 
 				for(keys(%{$self->{_last_modified}}));
 		}
 	%{$self->{_last_modified}} = %h_temp;
 	store($self->{_last_modified}, $self->{_filename});
 	return 1;
 	}
#-------------------------------------------------
 sub LtoR
 	{
 	my ($self, $ra_lp) = @_;
 	my $ra_rp = [];
 	my $rp;
 	for(@$ra_lp)
 		{
 		$rp = $_;
 		$rp =~ s!$self->{_regex_localdir}!$self->{_remotedir}!;
 		push(@$ra_rp, $rp);
 		}
 	return $ra_rp;
 	}
#-------------------------------------------------
 sub RtoL
 	{
 	my ($self, $ra_rp) = @_;
 	my $ra_lp = [];
 	my $lp;
 	for(@$ra_rp)
 		{
 		$lp = $_;
 		$lp =~ s!$self->{_regex_remotedir}!$self->{_localdir}!;
 		push(@$ra_lp, $lp);
 		}
 	return $ra_lp;
 	}
#-------------------------------------------------
1;
#------------------------------------------------
__END__

=head1 NAME

Net::UploadMirror - Perl extension for mirroring a local directory via FTP to the remote location

=head1 SYNOPSIS

  use Net::UploadMirror;
  my $um = Net::UploadMirror->new(
 	ftpserver		=> 'my_ftp.hostname.com',
 	user		=> 'my_ftp_user_name',
 	pass		=> 'my_ftp_password',
 	);
 $um->Upload();
 
 or more detailed:

 my $md = Net::UploadMirror->new(
 	ftpserver		=> 'my_ftp.hostname.com',
 	user		=> 'my_ftp_user_name',
 	pass		=> 'my_ftp_password',
 	localdir		=> 'home/nameA/homepageA',
 	remotedir	=> 'public',
 	debug		=> 1 # 1 for yes, 0 for no
 	timeout		=> 60 # default 30
 	delete		=> 'enable' # default 'disabled'
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
 $um->Upload();

=head1 DESCRIPTION

This module is for mirroring a local directory to a remote location via FTP.
For example websites, documentations or developmentstuff which ones were
worked on locally. Remote files on the ftp-server will be overwritten,
also in case they are newer. It is not developt for mirroring large archivs.
But there are not in principle any limits.

=head1 Constructor and Initialization
=item (object) new (options)
 Net::UploadMirror is a derived class from Net::MirrorDir.
 For detailed information about constructor or options
 read the documentation of Net::MirrorDir.

=head2 methods

=item (1) _Init (%arg)
 This function is called by the constructor.
 You do not need to call this function by yourself.

=item (1|0) Upload (void)
 Call this function for mirroring automatically, recommended!!!

=item (ref_hash_modified_files) CheckIfModified (ref_array_local_files)
 Takes a hashreference of local filenames to compare the last modification time,
 which is stored in a file, named by the attribute "filename", while uploading. 
 Returns a reference of a list.

=item (1) UpdateLastModified (ref_array_local_files)
 Update the stored modified-times of the local files.

=item (1|0) StoreFiles (ref_array_paths)
 Takes a arrayreference of local-paths to upload the files via FTP.

=item (1|0) MakeDirs (ref_array_paths)
 Takes a arrayreference of directories to make in the remote location.

=item (1|0) DeleteFiles (ref_array_paths)
 Takes a arrayreference of files to delete in the remote location.

=item (1|0) RemoveDirs (ref_array_paths)
 Takes a arrayreference of directories to remove in the remote location.

=item (1) CleanUp (ref_array_paths)
 Takes a arrayreference of directories to compare with the keys 
 in the {_last_modified} hash. Is the key not in the array or
 the value in the hash is incorrect, the key will be deleted.

=item (ref_array_local_paths) RtoL (ref_array_remote_paths)
 Takes a arrayreference of Remotepathnames and returns
 a arrayreference of the corresponding Localpathnames.

=item (ref_array_remote_paths) LtoR (ref_array_local_paths)
 Takes a arrayreference of Localpathnames and returns
 a arrayreference of the corresponding Remotepathnames.

=head2 optional options

=item filename
 The name of the file in which the last modified times will be stored.
 default = 'lastmodified_local'

=item delete
 When directories or files are to be deleted = 'enable'
 default = 'disabled'
 
=head2 EXPORT

None by default.

=head1 SEE ALSO

 Net::MirrorDir
 Net::DownloadMirror
 Tk::Mirror
 http://freenet-homepage/torstenknorr/index.html

=head1 FILES

 Net::MirrorDir 0.19
 Storable

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
