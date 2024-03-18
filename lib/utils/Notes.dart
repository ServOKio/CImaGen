class Notes{
  var tree = {
    'DPM++ 2M SDE Karras': {
      'upscalers': {
        'all': {
          'Lanczos': {
            'description': 'Softer, blurred details'
          },
          'R-ESRGAN 4x+': {
            'description': 'Sharper details, geometry correction, does not require additional processing',
            'denoising': 0.4
          }
        },
        'main': {
          'soft': 'Lanczos',
          'sharp': 'R-ESRGAN 4x+'
        }
      },
    },
    'Euler a': {
      'upscalers': {
        'all': {
          'Latent': {
            'description': '-'
          },
          'Latent (antialiased)': {
            'description': '-'
          },
          'Latent (bicubic)': {
            'description': 'More correct geometry, details look more plausible'
          },
          'Latent (bicubic antialiased)': {
            'description': 'Unlike the non-antialiased method, it breaks the geometry in some places and adds a BIT of noise and blur'
          },
          'Latent (nearest)': {
            'parent': 'Latent (bicubic)',
            'description': 'It differs from the bicubic method in more stable proportions and adds a little more realism, can change objects',
            'recommended_denoising_less': 0.35
          },
          'Latent (nearest-exact)': {
            'parent': 'Latent (bicubic)',
            'description': 'Unlike the bicubic method, it adds more detail and less realism, but breaks the geometry where it clearly should be',
          },
          'Lanczos': {
            'child': 'Latent',
            'description': 'There are fewer details than in the Latent method and more blurred, but it has the correct geometry and proportions'
          },
          'Nearest': {
            'parent': 'Lanczos',
            'stable': true,
            'description': 'More detailed than the Lanczos method, much better geometry and color management'
          },
          '4x-UltraMix_Smooth': {
            'parent': 'Lanczos',
            'description': 'Sharper details, geometry correction, but sometimes does not understand what should be between or inside the object',
          },
          '4x-UltraSharp': {
            'parent': 'Lanczos',
            'description': 'Much sharper details, sometimes adds extra garbage + problems with proportions, geometry correction, but sometimes does not understand what should be between or inside the object',
          },
          '4x_foolhardy_Remacri': {
            'parent': 'Lanczos',
            'description': 'Much sharper details, geometry correction, also corrects geometry in small details, but sometimes does not understand what should be between or inside the object.',
          },
          'ESRGAN_4x': {
            'parent': 'Lanczos',
            'description': 'Adds noise, correction of proportions and colors, as well as correct geometry in small details',
          },
          'LDSR': {
            'parent': 'Lanczos',
            'description': 'Contrast of small details, correction of proportions, color correction, but the contrast is too strong',
          },
          'R-ESRGAN 4x+': {
            'parent': 'Lanczos',
            'description': 'Correction of geometry, more correct proportions, understands what he is doing, has a soft blurred',
          },
          'R-ESRGAN 4x+ Anime6B': {
            'parent': 'Lanczos',
            'description': 'A more cartoonish look, breaks the geometry, but corrects the proportions',
          },
          'Real_HAT_GAN_SRx4': {
            'parent': 'Lanczos',
            'description': 'Weak cartoon appearance, blurs a little, breaks the geometry, but corrects the proportions',
          },
          'ScuNET': {
            'parent': 'Lanczos',
            'description': 'The same as Lanczos, but slightly more detailed and blurred',
          },
          'ScuNET PSNR': {
            'parent': 'Lanczos',
            'description': 'The same as ScuNET ? 1х1',
          },
          'SwinIR_4x': {
            'child': 'ESRGAN_4x',
            'description': 'Softer and fewer details',
          }
        },
        'main': {
          'soft': '-',
          'sharp': '-'
        }
      }
    }
  };
}