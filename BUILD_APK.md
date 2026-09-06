# สร้าง APK โดยไม่ต้องติดตั้ง Flutter บนโทรศัพท์

โปรเจกต์นี้มี GitHub Actions สำหรับสร้าง APK ให้อัตโนมัติ

## ขั้นตอน
1. สร้าง repository ใหม่บน GitHub
2. อัปโหลดไฟล์และโฟลเดอร์ทั้งหมดของโปรเจกต์นี้เข้า repository
3. เปิดแท็บ Actions
4. เลือก `Build My Home APK`
5. กด `Run workflow`
6. รอให้การ Build สำเร็จ
7. เปิดงานที่สร้างเสร็จ แล้วดาวน์โหลด Artifact ชื่อ `my-home-release-apk`
8. แตกไฟล์ artifact แล้วจะพบ `app-release.apk`
9. ติดตั้ง APK บนโทรศัพท์ Android

หมายเหตุ: GitHub ต้องใช้บัญชีและอินเทอร์เน็ตในการ build และดาวน์โหลด APK
