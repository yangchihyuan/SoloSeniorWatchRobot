import os
from glob import glob
from setuptools import find_packages, setup

package_name = 'audio_video_receiver'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # Add this line to install all .launch.py files from the launch directory.
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
            # Format: 'command_name = package_folder.filename:main_function'
            'my_node = audio_video_receiver.my_node:main',
            # Add these two entries.
            'my_pub = audio_video_receiver.my_publisher:main',
            'my_sub = audio_video_receiver.my_subscriber:main',            
            # Add these two entries.
            'my_server = audio_video_receiver.my_service_server:main',
            'my_client = audio_video_receiver.my_service_client:main',
            'android_av_bridge = audio_video_receiver.android_av_bridge:main',
        ],
    },
)
