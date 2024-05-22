<a href="https://flutter.dev/">
  <h4 align="center">
    <picture>
      <img alt="Flutter" height="300px" src="preview/icon.png">
    </picture>
  </h4>
</a>
<h1 align="center">CImaGen</h1>
<p align="center">"What the hell is the difference between them?!"</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white"/>
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>
  <img src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white"/>
  <img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white"/>
</p>

## About CImaGen

Initially, I just needed some simple application to get exif data from an image to view the generation parameters, but then I wanted to do something more that would help me generate images

## What's here?

At the moment, a gallery, a comparison of images and their parameters, a render history and a settings page are available.

### Comparison
Comparison allows you to select several images and compare them with each other. It can be very useful to find the best combination of promt, sampler and hires-upscaler. You have:
1. The histogram. We don't know why lol, but maybe it will be useful to someone, for example, when adjusting the color in ComfUI
2. Information about the file. Its compression method, color depth and size
3. Generation parameters. Soon we will add a feature to find errors and solve them

![image](preview/comparison.gif)

|||
| ------------- | ------------- |
| <h4>Find the difference</h4> The brighter the area, the more strongly it is changed  | <img src="preview/gif_1.gif" width="300px"/>  |
| <h4>Split view</h4> Put the images next to each other to choose the best one | <img src="preview/gif_2.gif" width="300px"/>  |
| <h4>Reading metadata and generation parameters</h4> Reading data from Topaz Photo AI, Photoshop, NovelAI, ArtBot, Adobe ImageReady, Celsus Studio Tool, Tensor Art, PhotoScape, A1111 and more | <img src="preview/gif_3.gif" width="300px"/>  |
| <h4>Notes</h4> As much as you want and whatever you want | <img src="preview/gif_4.gif" width="300px"/>  |

### Status
In order not to drown in ideas and bugs, we have a [page](https://github.com/users/ServOKio/projects/6) dedicated to progress.

## Building

> [!WARNING]
> At the moment, the structure of tables in databases is constantly changing, so please do not try to build the application until I deal with this piece of nastiness.

1. Android studio
2. Visual studio 2019 ~16.11 (why 16.11 ? Because the Clang compiler that is needed for the [rive](https://github.com/rive-app/rive-flutter/issues/369#issuecomment-2022541422) plugin is in this version) + "Desktop development with C++"
3. CMake version 3.14.0 (Note: if you are using Visual Studio 2019 and get the error "Could not create named generator Visual Studio 16 2019" then you need to replace CMake inside Visual Studio with version 3.14. Just install CMake 3.14 and replace all files in ~`C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin` to 3.14 files)

## Contact
[![Telegram badge][]][Telegram instructions]
[![Discord badge][]][Discord instructions]

[Telegram instructions]: https://t.me/servokio
[Telegram badge]: https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white
[Discord instructions]: https://discord.gg/hqveSV6wH7
[Discord badge]: https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white
