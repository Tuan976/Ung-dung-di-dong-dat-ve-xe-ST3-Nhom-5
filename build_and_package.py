import os
import subprocess
import zipfile
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.join(BASE_DIR, 'frontend')
DIST_DIR = os.path.join(FRONTEND_DIR, 'dist')
ZIP_PATH = os.path.join(BASE_DIR, 'dist_deploy.zip')

def main():
    print("=== [1/3] Dang chay build React frontend... ===")
    try:
        # Run npm run build
        subprocess.run('npm run build', shell=True, cwd=FRONTEND_DIR, check=True)
        print("v Build React thanh cong!")
    except subprocess.CalledProcessError as e:
        print(f"x Loi khi chay npm run build: {e}")
        return
    except Exception as e:
        print(f"x Loi khong xac dinh khi build: {e}")
        return

    print("\n=== [2/3] Dang tao file nen dist_deploy.zip... ===")
    if not os.path.exists(DIST_DIR):
        print(f"x Thu muc dist khong ton tai o: {DIST_DIR}")
        return

    try:
        if os.path.exists(ZIP_PATH):
            os.remove(ZIP_PATH)
            print("v Da xoa file zip cu.")

        # Zip frontend/dist folder with internal structure 'frontend/dist/...'
        # so extracting at host root automatically places them in the right place!
        with zipfile.ZipFile(ZIP_PATH, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(DIST_DIR):
                for file in files:
                    file_path = os.path.join(root, file)
                    # Relative path to BASE_DIR (e.g. 'frontend/dist/assets/index.js')
                    rel_path = os.path.relpath(file_path, BASE_DIR)
                    zipf.write(file_path, rel_path)
        
        print(f"v Tao file {os.path.basename(ZIP_PATH)} thanh cong!")
    except Exception as e:
        print(f"x Loi khi nen file zip: {e}")
        return

    print("\n=== [3/3] HUONG DAN TRIEN KHAI LEN HOST ===")
    print("1. Upload file 'dist_deploy.zip' len thu muc goc cua Host (cPanel).")
    print("2. Giai nen (Extract) file zip nay truc tiep tai thu muc goc.")
    print("   -> File se tu dong ghi de chinh xac vao thu muc 'frontend/dist/'.")
    print("3. Khoi dong lai ung dung Python (Restart python app) tren cPanel de Flask nhan file moi.")
    print("\n=== HOAN THANH! ===")

if __name__ == '__main__':
    main()
