# Database management

* DIRAC handles most DBs currently, exception AuthDB
* pre-install batch job creates the missing bits of schema
* eventually, alambic

## Chart database defaults

The chart lists its built-in databases under `diracx.sqlDbs.dbs` and
`diracx.osDbs.dbs`. When adding a database for a feature enabled by default in
DiracX, add it to the corresponding map in the chart.

For external servers, create the MySQL databases and grant access before
installing or upgrading. Set `host`, `user`, `password`, `rootUser`, and
`rootPassword` in the corresponding `default` section or override them per
database under `dbs`.

The chart also configures `PilotLogsDB` using the shared OpenSearch settings.
If you configure each OpenSearch database individually, provide settings for
`PilotLogsDB` or set `diracx.osDbs.dbs.PilotLogsDB` to `null` to omit it.

Set a built-in database to `null` in your values to omit it from chart setup.
Use `{}` to select a database with shared settings. Any DiracX feature still
enabled must have access to the databases it needs.
