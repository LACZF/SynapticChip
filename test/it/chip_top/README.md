# Test for chip

## Prepare

### Prepare instructions.hex(option)
```bash
cd $REPO_TOP_DIR/test/it/chip_top/
./build_program.sh
```


## Test cmd

### Test by uart
```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top/makefile_uart.txt
```
### Test base instructions by hex.
```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top/makefile_base.txt
```
