# Test for chip

## Test cmd

### Default test(test by uart)
```bash
cd $REPO_TOP_DIR
make test M=test/it/top_system
```
### Test instructions by hex.
```bash
cd $REPO_TOP_DIR
make test M=test/it/top_system TEST_ARGS="-DROM_PRG=\\\"instructions.hex\\\" -DSPM_PRG=\\\"instructions.hex\\\" -DSIM_CYCLE=100000"
```
