my $avatar_url = "http://somewhere/my-pic.jpg";

test "PUT /profile/:user_id/avatar_url sets my avatar",
   requires => [qw( do_request_json_authed )],

   check => sub {
      my ( $do_request_json_authed ) = @_;

      $do_request_json_authed->(
         method => "GET",
         uri    => "/profile/:user_id/avatar_url",
      )->then( sub {
         my ( $body ) = @_;

         ref $body eq "HASH" or die "Expected JSON object\n";

         defined $body->{avatar_url} or die "Expected 'avatar_url'\n";

         $body->{avatar_url} eq $avatar_url or die "Wrong avatar_url\n";

         provide can_set_avatar_url => 1;

         Future->done(1);
      });
   },

   do => sub {
      my ( $do_request_json_authed ) = @_;

      $do_request_json_authed->(
         method => "PUT",
         uri    => "/profile/:user_id/avatar_url",

         content => {
            avatar_url => $avatar_url,
         },
      );
   };

test "GET /profile/:user_id/avatar_url publicly accessible",
   requires => [qw( first_http_client can_login can_set_avatar_url )],

   check => sub {
      my ( $http, $login ) = @_;
      my ( $user_id ) = @$login;

      $http->do_request_json(
         method => "GET",
         uri    => "/profile/$user_id/avatar_url",
         # no access_token
      )->then( sub {
         my ( $body ) = @_;

         ref $body eq "HASH" or die "Expected JSON object\n";

         defined $body->{avatar_url} or die "Expected 'avatar_url'\n";

         $body->{avatar_url} eq $avatar_url or die "Wrong avatar_url\n";

         Future->done(1);
      });
   };