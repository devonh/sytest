prepare "More local room members",
   requires => [qw( do_request_json_for flush_events_for more_users room_id
                    can_join_room_by_id )],

   do => sub {
      my ( $do_request_json_for, $flush_events_for, $more_users, $room_id ) = @_;

      Future->needs_all( map {
         my $user = $_;

         $flush_events_for->( $user )->then( sub {
            $do_request_json_for->( $user,
               method => "POST",
               uri    => "/rooms/$room_id/join",

               content => {},
            );
         });
      } @$more_users );
   };

test "New room members see their own join event",
   requires => [qw( await_event_for more_users room_id
                    can_join_room_by_id )],

   await => sub {
      my ( $await_event_for, $more_users, $room_id ) = @_;

      Future->needs_all( map {
         my $user = $_;

         $await_event_for->( $user, sub {
            my ( $event ) = @_;
            return unless $event->{type} eq "m.room.member";

            json_keys_ok( $event, qw( type room_id user_id membership ));
            return unless $event->{room_id} eq $room_id;
            return unless $event->{user_id} eq $user->user_id;

            $event->{membership} eq "join" or
               die "Expected user membership as 'join'";

            return 1;
         });
      } @$more_users );
   };

test "New room members see room state in room initialSync",
   requires => [qw( do_request_json_for user more_users room_id
                    can_join_room_by_id can_room_initial_sync )],

   check => sub {
      my ( $do_request_json_for, $first_user, $more_users, $room_id ) = @_;

      Future->needs_all( map {
         my $user = $_;

         $do_request_json_for->( $user,
            method => "GET",
            uri    => "/rooms/$room_id/initialSync",
         )->then( sub {
            my ( $body ) = @_;

            my %presence;
            $presence{$_->{content}{user_id}} = $_ for @{ $body->{presence} };

            $presence{$first_user->user_id} or
               die "Expected to find initial user's presence";

            json_keys_ok( $presence{$first_user->user_id}, qw( type content ));
            json_keys_ok( $presence{$first_user->user_id}{content},
               qw( presence status_msg last_active_ago ));

            Future->done(1);
         });
      } @$more_users );
   };

test "Existing members see new members' join events",
   requires => [qw( await_event_for user more_users room_id
                    can_join_room_by_id )],

   await => sub {
      my ( $await_event_for, $user, $more_users, $room_id ) = @_;

      Future->needs_all( map {
         my $other_user = $_;

         $await_event_for->( $user, sub {
            my ( $event ) = @_;
            return unless $event->{type} eq "m.room.member";
            json_keys_ok( $event, qw( type room_id user_id membership ));
            return unless $event->{room_id} eq $room_id;
            return unless $event->{user_id} eq $other_user->user_id;

            $event->{membership} eq "join" or
               die "Expected user membership as 'join'";

            return 1;
         });
      } @$more_users );
   };

test "Existing members see new members' presence",
   requires => [qw( await_event_for user more_users
                    can_join_room_by_id )],

   await => sub {
      my ( $await_event_for, $user, $more_users ) = @_;

      Future->needs_all( map {
         my $other_user = $_;

         $await_event_for->( $user, sub {
            my ( $event ) = @_;
            return unless $event->{type} eq "m.presence";
            json_keys_ok( $event, qw( type content ));
            json_keys_ok( my $content = $event->{content}, qw( user_id presence ));
            return unless $content->{user_id} eq $other_user->user_id;

            return 1;
         });
      } @$more_users );
   };