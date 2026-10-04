# Copies of FairWear's shared logic

Every `.ets` file under this folder is an unchanged copy of the file with the same path under
`common/src/main/ets/` in the FairWear project. Health Sim uses them so both apps generate, write and read the
very same data (`health/HealthSimPayload.ets`). Never edit a copy here: change the file in `common/` and copy
it again. `common/src/test/HealthSimCopies.test.ets` fails when a copy differs.
