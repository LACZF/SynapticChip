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

### Test pe module only
```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top APPEND_ARGS='-DPE_TEST_FOR_CHIP_TOP'
```

### Test timer module only
```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top APPEND_ARGS='-DTIMER_TEST_FOR_CHIP_TOP'
```

### Test spi module only
```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top APPEND_ARGS='-DSPI_TEST_FOR_CHIP_TOP'
```

### Test gpio module only
```bash
cd $REPO_TOP_DIR
make test M=test/it/chip_top APPEND_ARGS='-DGPIO_TEST_FOR_CHIP_TOP'
```