# Test for chip

## Prepare

### Prepare instructions.hex and data_bss.hex(option)
```bash
cd $REPO_TOP_DIR/test/it/chip_top/
./build_program.sh
```


## Test cmd

```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top
```

### Specify ram and rom to content for testing.

```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top ROM_PRG=program.hex RAM_PRG=data_bss.hex
```
