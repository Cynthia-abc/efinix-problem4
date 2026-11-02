"""Ti60 five-mode demo panel. UART 115200 8N1, ASCII 0..4, A/B/C box count.

The FPGA echoes a digit after committing the mode during vertical blanking.
The UI never treats write() completion as a hardware acknowledgment.
"""
from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import sys
import time
import tkinter as tk
from tkinter import messagebox, ttk

sys.path.insert(0, str(Path(__file__).resolve().parent / "vendor"))
try:
    import serial
    from serial.tools import list_ports
except ImportError:
    serial = None
    list_ports = None

MODES = (
    ("彩色原图", "摄像头实时画面 · 色彩展示"),
    ("灰度 / 白色边缘", "左灰度、右黑底白边缘\n玩偶 · 汉字 · 字母 · 棋盘格"),
    ("彩色边缘叠加", "全屏彩色原图＋红色边缘\n棋盘格 · 调阈值 · 冻结回放"),
    ("多目标几何分析", "全画面最多三个候选＋数值统计\n边缘数 · 包围盒 · 长宽比 · 轮廓步数"),
    ("圆形 / 矩形识别", "独立轻量几何规则分类\n适合清晰、孤立的演示目标"),
)


class ModePanel:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.link = None
        self.pending = None
        self.deadline = 0.0
        self.port_names = {}
        self.buttons = []
        self.slot_buttons = []
        root.title("Ti60 图像处理演示台")
        root.geometry("940x790")
        root.minsize(820, 720)
        root.configure(bg="#eef2f6")
        root.protocol("WM_DELETE_WINDOW", self.close)
        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure("TFrame", background="#eef2f6")
        style.configure("TLabel", background="#eef2f6", font=("Microsoft YaHei UI", 10))
        style.configure("TButton", font=("Microsoft YaHei UI", 10), padding=8)
        style.configure("TCheckbutton", background="#eef2f6", font=("Microsoft YaHei UI", 10))
        style.configure("Title.TLabel", font=("Microsoft YaHei UI", 23, "bold"), foreground="#10263b")
        style.configure("Status.TLabel", font=("Microsoft YaHei UI", 12, "bold"), foreground="#155d8b")
        outer = ttk.Frame(root, padding=24)
        outer.pack(fill="both", expand=True)
        ttk.Label(outer, text="Ti60 图像处理演示台", style="Title.TLabel").pack(anchor="w")
        ttk.Label(outer, text="按演示顺序切换画面，图像显示在 HDMI 屏幕上。", foreground="#526579").pack(anchor="w", pady=(5, 16))

        connection = ttk.Frame(outer)
        connection.pack(fill="x")
        ttk.Label(connection, text="串口").pack(side="left", padx=(0, 8))
        self.port = tk.StringVar()
        self.combo = ttk.Combobox(connection, textvariable=self.port, width=32)
        self.combo.pack(side="left", fill="x", expand=True)
        ttk.Button(connection, text="刷新", command=self.refresh_ports).pack(side="left", padx=8)
        self.connect_button = ttk.Button(connection, text="连接", command=self.toggle_connection)
        self.connect_button.pack(side="left")
        ttk.Label(connection, text="115200 · 8N1", foreground="#526579").pack(side="left", padx=(12, 0))
        self.use_ack = tk.BooleanVar(value=True)
        self.ack_checkbox = ttk.Checkbutton(outer, variable=self.use_ack,
            text="已连接回传线：FPGA TX → USB-TTL RX（推荐，可确认切换）")
        self.ack_checkbox.pack(anchor="w", pady=(10, 10))
        self.status = tk.StringVar(value="未连接 · 选择 USB-TTL 的 COM 口后点击连接")
        status_label = ttk.Label(outer, textvariable=self.status, style="Status.TLabel", wraplength=870)
        status_label.pack(fill="x", pady=(0, 12))

        cards = ttk.Frame(outer)
        cards.pack(fill="x")
        for mode, (title, detail) in enumerate(MODES):
            frame = tk.Frame(cards, bg="white", highlightthickness=1, highlightbackground="#d5dee8")
            frame.grid(row=mode // 2, column=mode % 2, padx=(0, 10) if mode % 2 == 0 else (0, 0),
                       pady=(0, 10), sticky="nsew")
            tk.Label(frame, text=f"{mode}   {title}", bg="white", fg="#10263b",
                     font=("Microsoft YaHei UI", 15, "bold"), anchor="w").pack(fill="x", padx=16, pady=(12, 3))
            tk.Label(frame, text=detail, bg="white", fg="#526579", height=2,
                     font=("Microsoft YaHei UI", 10), anchor="w", justify="left").pack(fill="x", padx=16)
            button = ttk.Button(frame, text=f"切换到模式 {mode}", command=lambda m=mode: self.select_mode(m))
            button.pack(fill="x", padx=16, pady=(9, 12))
            self.buttons.append(button)
            if mode == 3:
                tk.Label(frame, text="显示框数量（分析仍保留前三候选）", bg="white", fg="#526579",
                         font=("Microsoft YaHei UI", 9), anchor="w").pack(fill="x", padx=16, pady=(0, 2))
                slots = tk.Frame(frame, bg="white")
                slots.pack(fill="x", padx=12, pady=(0, 10))
                for count in (1, 2, 3):
                    slot_button = ttk.Button(slots, text=f"显示 {count} 个",
                                             command=lambda n=count: self.select_slots(n))
                    slot_button.pack(side="left", expand=True, fill="x", padx=4)
                    self.slot_buttons.append(slot_button)
        cards.columnconfigure(0, weight=1, uniform="cards")
        cards.columnconfigure(1, weight=1, uniform="cards")
        tips = ("板载操作：K1 短按提高阈值，K2 短按降低阈值；双键同时按冻结 / 恢复；"
                "K1 / K2 长按调用前 / 后帧回放。回放顺序和保留帧数沿用当前 FPGA 版本。")
        tips_label = ttk.Label(outer, text=tips, wraplength=870, foreground="#526579")
        tips_label.pack(fill="x", pady=(0, 8))
        outer.bind("<Configure>", lambda event: [label.configure(wraplength=max(300, event.width - 48))
                                                for label in (status_label, tips_label)])
        self.log = tk.Text(outer, height=4, font=("Consolas", 10), bg="#10263b", fg="#d9e5ee",
                           relief="flat", padx=10, pady=7, state="disabled")
        self.log.pack(fill="both", expand=True)
        for mode in range(5):
            root.bind(str(mode), lambda event, m=mode: self.hotkey(event, m))
        self.refresh_ports()
        self.set_mode_buttons(False)
        root.after(50, self.poll)

    def write_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", f"{datetime.now():%H:%M:%S}  {text}\n")
        # Bound long rehearsal sessions without clearing recent evidence.
        if int(self.log.index("end-1c").split(".")[0]) > 300:
            self.log.delete("1.0", "51.0")
        self.log.see("end")
        self.log.configure(state="disabled")

    def refresh_ports(self):
        if list_ports is None:
            self.write_log("缺少 pyserial，请双击首次安装依赖.cmd。")
            return
        self.port_names = {f"{p.device} — {p.description}": p.device for p in list_ports.comports()}
        self.combo["values"] = tuple(self.port_names)
        if self.port.get() not in self.port_names and self.port_names and not self.link:
            self.port.set(next(iter(self.port_names)))

    def set_mode_buttons(self, enabled):
        for button in self.buttons:
            button.configure(state="normal" if enabled else "disabled")
        for button in self.slot_buttons:
            button.configure(state="normal" if enabled else "disabled")

    def toggle_connection(self):
        if self.link:
            self.disconnect()
            return
        if serial is None:
            messagebox.showerror("需要安装依赖", "请先双击“首次安装依赖.cmd”。")
            return
        device = self.port_names.get(self.port.get(), self.port.get().strip())
        if not device:
            messagebox.showinfo("选择串口", "插入 USB-TTL，点击刷新，再选择对应的 COM 口。")
            return
        link = serial.Serial(port=None, baudrate=115200, bytesize=8, parity="N", stopbits=1,
                             timeout=0, write_timeout=0.3, xonxoff=False, rtscts=False, dsrdtr=False)
        try:
            link.dtr = False
            link.rts = False
            link.port = device
            link.open()
            link.reset_input_buffer()
        except (serial.SerialException, OSError, ValueError) as error:
            link.close()
            messagebox.showerror("连接失败", f"{error}\n\n请确认 COM 口正确，并关闭占用该端口的 SSCom。")
            return
        self.link = link
        self.combo.configure(state="disabled")
        self.ack_checkbox.configure(state="disabled")
        self.connect_button.configure(text="断开")
        self.set_mode_buttons(True)
        self.status.set("已连接 · 尚未确认 FPGA 画面模式")
        self.write_log(f"连接 {device}，115200 8N1")
        if self.use_ack.get():
            self.transmit(b"?", "查询当前模式", expected="query")

    def disconnect(self, reason="已断开连接"):
        if self.link:
            try:
                self.link.close()
            except (OSError, serial.SerialException):
                pass
        self.link = None
        self.pending = None
        self.combo.configure(state="normal")
        self.ack_checkbox.configure(state="normal")
        self.connect_button.configure(text="连接")
        self.set_mode_buttons(False)
        self.status.set(reason)
        self.write_log(reason)

    def transmit(self, data, description, expected):
        if not self.link or self.pending is not None:
            return
        try:
            count = self.link.write(data)
            if count != len(data):
                raise OSError("命令未完整发送")
        except (serial.SerialException, OSError) as error:
            self.disconnect(f"串口异常：{error}")
            return
        self.write_log(f"发送 {data!r} · {description}")
        if self.use_ack.get():
            self.pending = expected
            self.deadline = time.monotonic() + 1.5
            self.set_mode_buttons(False)
            self.status.set(f"{description} · 等待 FPGA 确认…")
        else:
            self.status.set(f"{description} · 已发送，未启用回传确认，请查看 HDMI")

    def select_mode(self, mode):
        self.transmit(str(mode).encode("ascii"), f"模式 {mode}：{MODES[mode][0]}", expected=mode)

    def select_slots(self, count):
        code = chr(ord("A") + count - 1).encode("ascii")
        self.transmit(code, f"模式3显示 {count} 个候选框", expected=f"slots{count}")

    def hotkey(self, event, mode):
        if event.widget is self.combo or isinstance(event.widget, (tk.Entry, ttk.Entry, tk.Text)):
            return
        if self.link and self.pending is None:
            self.select_mode(mode)

    def receive(self, payload):
        for byte in payload:
            if 0x30 <= byte <= 0x34:
                mode = byte - 0x30
                self.write_log(f"FPGA 已应用模式 {mode}：{MODES[mode][0]}")
                if self.pending in (None, "query", mode):
                    self.pending = None
                    self.set_mode_buttons(bool(self.link))
                    self.status.set(f"FPGA 已确认 · 模式 {mode}：{MODES[mode][0]}")
                else:
                    self.status.set(f"FPGA 当前模式 {mode} · 仍在等待所选模式确认…")
            elif 0x41 <= byte <= 0x43:
                count = byte - 0x40
                self.write_log(f"FPGA 已应用模式3显示 {count} 个候选框")
                if self.pending in (None, f"slots{count}"):
                    self.pending = None
                    self.set_mode_buttons(bool(self.link))
                    self.status.set(f"FPGA 已确认 · 模式3显示 {count} 个候选框")

    def poll(self):
        if self.link:
            try:
                waiting = self.link.in_waiting
                if waiting:
                    self.receive(self.link.read(min(waiting, 256)))
            except (serial.SerialException, OSError) as error:
                self.disconnect(f"串口连接中断：{error}")
            if self.pending is not None and time.monotonic() > self.deadline:
                self.pending = None
                self.set_mode_buttons(bool(self.link))
                self.status.set("未收到确认 · 请检查 RX 回传线、新 bit 和串口电平；可重试")
                self.write_log("确认超时；发送成功不代表画面已经切换。")
        self.root.after(50, self.poll)

    def close(self):
        if self.link:
            self.link.close()
        self.root.destroy()


def self_test():
    """Exercise real pyserial loopback and GUI state without touching COM ports."""
    if serial is None:
        raise SystemExit("pyserial missing")
    root = tk.Tk()
    root.withdraw()
    panel = ModePanel(root)
    link = serial.serial_for_url("loop://", baudrate=115200, timeout=0, write_timeout=0.3)
    panel.link = link
    panel.set_mode_buttons(True)
    for mode in range(5):
        panel.select_mode(mode)
        assert panel.pending == mode
        assert all(str(b["state"]) == "disabled" for b in panel.buttons)
        assert "已确认" not in panel.status.get()
        payload = link.read(1)
        assert payload == str(mode).encode("ascii")
        panel.receive(payload)  # transport loopback only; not FPGA hardware proof
        assert panel.pending is None
        assert f"模式 {mode}" in panel.status.get()
    for count in (1, 2, 3):
        panel.select_slots(count)
        assert panel.pending == f"slots{count}"
        assert link.read(1) == bytes([0x40 + count])
        panel.receive(bytes([0x40 + count]))
        assert panel.pending is None
    panel.pending = 3
    panel.receive(b"1")
    assert panel.pending == 3  # stale confirmation cannot release the pending command
    panel.deadline = 0
    panel.poll()
    assert panel.pending is None and "未收到确认" in panel.status.get()
    panel.use_ack.set(False)
    panel.select_mode(2)
    assert panel.pending is None and "未启用回传" in panel.status.get()
    assert link.read(1) == b"2"
    panel.disconnect()
    assert all(str(b["state"]) == "disabled" for b in panel.buttons)
    panel.close()
    print("PASS panel: five modes + three box-count commands, pending/ack/stale/timeout/TX-only/disconnect; loopback only")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        root = tk.Tk()
        ModePanel(root)
        root.mainloop()


if __name__ == "__main__":
    main()
