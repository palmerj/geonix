{ pkgs
, lib

, postgis

}:

let
  pg = pkgs.postgresql;

  postgresPackage = pg.withPackages (p: [ postgis ]);

  postgresServiceDir = ".geonix/services/postgres";

  postgresInitdbArgs = [ "--locale=C" "--encoding=UTF8" ];

  postgresConf =
    pkgs.writeText "postgresql.conf"
      ''
        listen_addresses = '*'
        port = ${toString postgresPort}

        log_connections = on
        log_destination = 'stderr'
        log_disconnections = on
        log_duration = on
        log_statement = 'all'
      '';

  postgresPort = 5432;

  entrypoint =
    pkgs.writeShellScriptBin "entrypoint"
      ''
        set -euo pipefail

        mkdir -p $PGDATA

        if [ ! -f $PGDATA/PG_VERSION ]; then

          # PostgreSQL initdb needs to see PGUSER user (postgres) in the system
          # during initdb phase which doesn't exist when running container as
          # our host system user. Below is the trick providing this illusion.

          uid="$(id -u)"
          gid="$(id -g)"

          NSS_WRAPPER_PASSWD="$(mktemp)"
          NSS_WRAPPER_GROUP="$(mktemp)"

          export LD_PRELOAD=${pkgs.nss_wrapper}/lib/libnss_wrapper.so NSS_WRAPPER_PASSWD NSS_WRAPPER_GROUP
          printf 'postgres:x:%s:%s:PostgreSQL:%s:/bin/false\n' "$uid" "$gid" "$PGDATA" > "$NSS_WRAPPER_PASSWD"
          printf 'postgres:x:%s:\n' "$gid" > "$NSS_WRAPPER_GROUP"

          initdb \
            --username $PGUSER \
            --pgdata $PGDATA \
            ${pkgs.lib.concatStringsSep " " postgresInitdbArgs}

          cat "${postgresConf}" >> $PGDATA/postgresql.conf
          echo "host  all  all  0.0.0.0/0  trust" >> $PGDATA/pg_hba.conf

          # End of PGUSER illusion.
          rm -f "$NSS_WRAPPER_PASSWD" "$NSS_WRAPPER_GROUP"
          unset LD_PRELOAD NSS_WRAPPER_PASSWD NSS_WRAPPER_GROUP

          echo -e "\nPostgreSQL init process complete. Ready for start up.\n"
        fi

        exec ${postgresPackage}/bin/"$@"
      '';


in
pkgs.dockerTools.buildLayeredImage
  {
    name = "geonix-postgres";
    tag = "latest";

    # Breaks reproducibility by setting current timestamp during each build.
    # created = "now";

    contents = [
      postgresPackage
      entrypoint

      pkgs.bash
      pkgs.coreutils
      pkgs.nss_wrapper
    ];

    extraCommands = ''
      mkdir data tmp
      chmod 777 data tmp
    '';

    maxLayers = 100;

    config = {
      Env = [
        "PGDATA=/data/${postgresServiceDir}"
        "PGHOST=/data/${postgresServiceDir}"
        "PGUSER=postgres"
        "PGPORT=${toString postgresPort}"
      ];

      Entrypoint = "${entrypoint}/bin/entrypoint";
      Cmd = [ "postgres" "-k" "/data/${postgresServiceDir}" ];
      Stopsignal = "SIGINT";

      Volumes = {
        "/data" = { };
      };

      ExposedPorts = {
        "5432/tcp" = { };
      };
    };
  } // {
  meta = {
    description = "PostgreSQL/PostGIS OCI compatible container image";
    homepage = "https://github.com/imincik/geonix";
    license = lib.licenses.mit;
    maintainers = [ pkgs.lib.maintainers.imincik ];
    platforms = lib.platforms.linux;
  };
}