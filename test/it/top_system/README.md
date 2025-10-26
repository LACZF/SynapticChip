# Test for chip

## Prepare

### Prepare instructions.hex(option)
```bash
cd $REPO_TOP_DIR/test/it/top_system/
./build_program.sh
```


## Test cmd

### Test by uart
```bash
cd $REPO_TOP_DIR
make test M=test/it/top_system/makefile_uart.txt
```
### Test base instructions by hex.
```bash
cd $REPO_TOP_DIR
make test M=test/it/top_system/makefile_base.txt
```
