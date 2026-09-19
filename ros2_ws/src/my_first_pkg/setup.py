import os
from glob import glob
from setuptools import find_packages, setup

package_name = 'my_first_pkg'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # 加入下面這一行！這會把 launch 目錄下所有 .launch.py 檔案安裝到系統中
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='chihyuan',
    maintainer_email='cyyang@cgu.edu.tw',
    description='TODO: Package description',
    license='TODO: License declaration',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            # 格式：'指令名稱 = 套件資料夾.檔名:主函數'
            'my_node = my_first_pkg.my_node:main',
            # 加入下面這兩行
            'my_pub = my_first_pkg.my_publisher:main',
            'my_sub = my_first_pkg.my_subscriber:main',            
            # 新增這兩行
            'my_server = my_first_pkg.my_service_server:main',
            'my_client = my_first_pkg.my_service_client:main',
        ],
    },
)
