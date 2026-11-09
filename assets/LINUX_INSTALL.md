# Linux Installation Guide for CCloud

## Tar.gz Archive

The tar.gz archive contains the raw application files.

### Running from tar.gz:

1. Extract the archive:
   ```bash
   tar -xzf CCloud-linux.tar.gz
   ```
2. Navigate to the bundle directory:
   ```bash
   cd bundle
   ```
3. Run the application:
   ```bash
   ./AppRun
   ```

## Troubleshooting

### Common Issues:

1. **"symbol lookup error: undefined symbol: g_once_init_enter_pointer"**
   This error occurs when there's a GLib version mismatch. The AppImage and packages should include all necessary libraries. If you still encounter this issue, try installing the required system libraries:
   ```bash
   sudo apt-get install libgtk-3-0 libglib2.0-0
   ```

2. **"execv error: No such file or directory"**
   Make sure the executable has proper permissions:
   ```bash
   chmod +x ccloud_gui
   ```

3. **Missing dependencies**
   Install required system libraries:
   ```bash
   sudo apt-get install libgtk-3-0 libgdk-pixbuf2.0-0 libglib2.0-0
   ```

### System Requirements:

- Linux kernel 4.4 or newer
- GLib 2.48 or newer
- GTK+ 3.20 or newer

## Building from Source:

To build CCloud from source, you need to install the required development libraries:

```bash
sudo apt-get install libmpv-dev libepoxy-dev librsvg2-dev libgirepository1.0-dev
```

These libraries are required by the media playback functionality and GTK plugin in CCloud.

For any issues not covered in this guide, please open an issue on our GitHub repository.
