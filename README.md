kali pro ghost edition – phiên bản tối giản
============================================

script tự động cho kali nethunter trên termux
không sử dụng icon, không ký tự đặc biệt
toàn bộ thông báo bằng chữ thường, có dấu tiếng việt

────────────────────────────────────────────
1. giới thiệu
────────────────────────────────────────────

kali pro ghost edition là script tự động hoá toàn bộ quá trình:
- cài đặt môi trường desktop xfce + kali desktop experience (kex)
- kết nối vpn tự động nếu có file cấu hình .ovpn
- chạy tor daemon để định tuyến dns qua tor
- thay đổi địa chỉ mac ngẫu nhiên
- kích hoạt chế độ tàng hình (stealth): hostname ngẫu nhiên, xoá log, ẩn panel, xoá lịch sử
- bật kill switch bằng iptables (chỉ cho phép vpn)
- tối ưu hiệu năng hệ thống (cpu, i/o, bộ nhớ, ipv6)
- monitor băng thông và kết nối mạng
- xoá sạch mọi dấu vết hoạt động
- chế độ panic dừng khẩn cấp toàn bộ tiến trình

script chạy hoàn toàn trong môi trường nethunter – termux
không yêu cầu nhập mật khẩu sudo trong quá trình sử dụng

────────────────────────────────────────────
2. yêu cầu
────────────────────────────────────────────

- termux đã cài đặt từ f-droid hoặc google play
- nethunter đã được cài đặt trong termux
  (hướng dẫn: https://www.kali.org/docs/nethunter/nethunter-rootless/)
- file cấu hình openvpn (tuỳ chọn) đặt tại ~/vpn.ovpn
- kết nối internet ổn định (để cài gói lần đầu)

────────────────────────────────────────────
3. cài đặt
────────────────────────────────────────────

bước 1: tải script về thư mục home

curl -o ~/kali-pro.sh https://raw.githubusercontent.com/your-repo/kali-pro.sh
hoặc tạo file thủ công:

nano ~/kali-pro.sh
(dán nội dung script vào, lưu và thoát)

bước 2: cấp quyền thực thi

chmod +x ~/kali-pro.sh

bước 3: chạy script lần đầu để tự động cài đặt gói

./kali-pro.sh

lần chạy đầu tiên script sẽ tự động:
- kiểm tra kết nối internet
- cài đặt các gói: xfce4, kali-desktop-xfce, kex, openvpn, tor, macchanger, iptables, bmon, iftop, nethogs
- cấu hình kex ở chế độ shared
- tối ưu hệ thống
- tạo file đánh dấu đã cài đặt

sau khi hoàn tất, menu chính sẽ hiện ra.

────────────────────────────────────────────
4. sử dụng
────────────────────────────────────────────

chạy script bất cứ lúc nào:

cd ~
./kali-pro.sh

menu sẽ hiển thị các lựa chọn sau:

1. khởi động hoàn chỉnh (desktop + vpn + tor + mac + stealth)
2. dừng tất cả dịch vụ
3. kích hoạt kill switch (chỉ vpn)
4. tắt kill switch
5. live network monitor
6. xóa sạch dấu vết (wipe traces)
7. tối ưu hệ thống
8. bật autostart (thêm vào .bashrc)
9. panic button – dừng khẩn cấp
10. thoát

bạn chỉ cần nhập số tương ứng và nhấn enter.

────────────────────────────────────────────
5. chi tiết các chức năng
────────────────────────────────────────────

5.1 khởi động hoàn chỉnh
- tắt compositor xfwm4 để giảm tải
- kết nối vpn (nếu có file ~/vpn.ovpn)
- khởi động tor
- thay đổi mac ngẫu nhiên tất cả interface (trừ lo)
- kích hoạt stealth (hostname, xoá log, ẩn panel, tắt noti)
- chạy kex --slim (vnc server)
- vnc listen tại localhost:5901, mật khẩu mặc định: kali

5.2 dừng tất cả dịch vụ
- dừng kex
- tắt openvpn
- tắt tor
- tắt kill switch
- xoá file lock

5.3 kill switch
- dùng iptables chặn mọi traffic không đi qua interface tun+
- chỉ cho phép loopback và vpn
- có thể bật/tắt riêng

5.4 network monitor
- chọn giữa bmon, iftop, nethogs
- hiển thị realtime

5.5 xoá dấu vết
- xoá lịch sử bash, zsh, fish
- xoá toàn bộ file .log trong /var/log
- xoá /tmp, /var/tmp
- xoá wtmp, btmp, lastlog
- yêu cầu xác nhận trước khi thực hiện

5.6 tối ưu hệ thống
- set cpu governor = performance
- swappiness = 10
- vfs_cache_pressure = 50
- i/o scheduler = deadline
- tăng network buffer
- tắt ipv6
- tắt bluetooth, cups, avahi-daemon
- dọn apt cache

5.7 autostart
- thêm dòng bash ~/kali-pro.sh vào cuối file ~/.bashrc
- mỗi lần mở termux mới, menu sẽ tự động hiện ra

5.8 panic button
- kill -9 toàn bộ tiến trình liên quan (kex, openvpn, tor, msf, wireshark, xfce4)
- reset iptables về accept tất cả
- xoá file lock
- hiển thị thông báo panic

────────────────────────────────────────────
6. cấu hình vpn (tuỳ chọn)
────────────────────────────────────────────

nếu bạn có tài khoản vpn, đặt file .ovpn vào:

~/vpn.ovpn

script sẽ tự động dùng file này khi chọn chức năng khởi động.
bạn có thể chỉnh sửa trực tiếp nội dung file nếu cần thay đổi.

────────────────────────────────────────────
7. lưu ý
────────────────────────────────────────────

- tất cả lệnh apt đều chạy ngầm, không hiển thị output
- nếu lần đầu cài đặt gói chậm, hãy kiểm tra kết nối mạng
- script không tự động kết nối wifi; bạn phải tự kết nối trước khi chạy
- chức năng kill switch chỉ hoạt động nếu iptables được phép (nethunter rootless có thể cần cấu hình thêm)
- để thoát khỏi menu chính, chọn option 10
- để thoát khẩn cấp bất cứ lúc nào: nhấn ctrl + c

────────────────────────────────────────────
8. gỡ cài đặt
────────────────────────────────────────────

nếu muốn xóa hoàn toàn script và các cấu hình:

rm -f ~/kali-pro.sh
rm -rf ~/.kali-pro

để xóa các gói đã cài, bạn có thể dùng lệnh trong nethunter:

nethunter -r apt remove --purge xfce4 kali-desktop-xfce kex openvpn tor macchanger iptables bmon iftop nethogs

────────────────────────────────────────────
9. tác giả
────────────────────────────────────────────

nguyễn tấn tài
────────────────────────────────────────────

phiên bản hiện tại: v6 – minimal (không icon, không ký tự đặc biệt)
cập nhật lần cuối: tháng 2 năm 2026
