using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

internal static class TrayHelper
{
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_APPWINDOW = 0x00040000;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr after,
        int x, int y, int cx, int cy, uint flags);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    private static string _commandFile;
    private static string _mouseFile;
    private static NotifyIcon _notify;
    private static Timer _timer;
    private static Timer _mouseTimer;
    private static int _parentPid;

    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Length < 3)
        {
            return;
        }
        var iconPath = args[0];
        _commandFile = args[1];
        _mouseFile = args.Length > 3 ? args[3] : "";
        _parentPid = int.Parse(args[2]);

        SetToolWindow();
        Application.EnableVisualStyles();
        _notify = new NotifyIcon();
        try
        {
            _notify.Icon = new Icon(iconPath);
        }
        catch (Exception)
        {
            return;
        }
        _notify.Text = "Stickman Pet";
        _notify.Visible = true;

        var menu = new ContextMenuStrip();
        AddCommand(menu, "显示/隐藏", "toggle");
        AddCommand(menu, "静音", "mute");
        AddCommand(menu, "置顶", "topmost");
        menu.Items.Add(new ToolStripSeparator());
        var quit = new ToolStripMenuItem("退出");
        quit.Click += delegate
        {
            WriteCommand("quit");
            _notify.Visible = false;
            Application.Exit();
        };
        menu.Items.Add(quit);
        _notify.ContextMenuStrip = menu;
        _notify.DoubleClick += delegate { WriteCommand("show"); };

        _timer = new Timer();
        _timer.Interval = 1000;
        _timer.Tick += delegate
        {
            try
            {
                Process.GetProcessById(_parentPid);
            }
            catch
            {
                _notify.Visible = false;
                Application.Exit();
            }
        };
        _timer.Start();

        if (!string.IsNullOrEmpty(_mouseFile))
        {
            _mouseTimer = new Timer();
            _mouseTimer.Interval = 16;
            _mouseTimer.Tick += delegate
            {
                try
                {
                    var point = Cursor.Position;
                    var down = (GetAsyncKeyState(0x01) & 0x8000) != 0;
                    File.WriteAllText(_mouseFile,
                        point.X + "," + point.Y + "," + (down ? "1" : "0"));
                }
                catch
                {
                }
            };
            _mouseTimer.Start();
        }

        Application.Run();
        _notify.Visible = false;
        _notify.Dispose();
    }

    private static void AddCommand(ContextMenuStrip menu, string text, string command)
    {
        var item = new ToolStripMenuItem(text);
        item.Click += delegate { WriteCommand(command); };
        menu.Items.Add(item);
    }

    private static void WriteCommand(string command)
    {
        File.AppendAllText(_commandFile, command + "\n");
    }

    private static void SetToolWindow()
    {
        for (var i = 0; i < 15; i++)
        {
            try
            {
                var process = Process.GetProcessById(_parentPid);
                var hwnd = process.MainWindowHandle;
                if (hwnd != IntPtr.Zero)
                {
                    var style = GetWindowLong(hwnd, GWL_EXSTYLE);
                    style = (style & ~WS_EX_APPWINDOW) | WS_EX_TOOLWINDOW;
                    SetWindowLong(hwnd, GWL_EXSTYLE, style);
                    SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0,
                        SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER |
                        SWP_NOACTIVATE | SWP_FRAMECHANGED);
                    return;
                }
            }
            catch
            {
                return;
            }
            System.Threading.Thread.Sleep(200);
        }
    }
}
