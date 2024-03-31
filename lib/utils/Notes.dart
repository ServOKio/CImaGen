class Notes{
  var hires = {
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
  Map<String, Author> authors = {
    'takahirosi': Author(
        name: 'takahirosi',
        blurred: Blured.slightly,
        rubber: true,
        looks: Looks.almostRealistic,
        asian: true,
        style: Style.outlineRealistic
    ),
    'voidlesky': Author(
        name: 'voidlesky',
        looks: Looks.shaded,
        style: Style.drawing,
        stable: false
    ),
    'braeburned': Author(
        name: 'braeburned',
        looks: Looks.coloredSketchShaded,
        style: Style.cartoon,
        sharpLine: true
    ),
    'taran_fiddler': Author(
        name: 'Taran Fiddler',
        looks: Looks.almostRealistic,
        style: Style.painting,
        detailed: Detailed.smallDetails
    ),
    'thebigslick': Author(
        name: 'The Big Slick',
        blurred: Blured.veryLittle,
        looks: Looks.coloredSketchShaded,
        style: Style.drawing,
        detailed: Detailed.smallDetails
    ),
    'enro_the_mutt': Author(
        name: 'Enro the mutt',
        looks: Looks.coloredSketchShaded,
        style: Style.drawing,
        detailed: Detailed.smallDetails
    ),
    'lvlirror': Author(
        name: 'lvlirror',
        looks: Looks.coloredSketchShaded,
        style: Style.drawing,
        detailed: Detailed.generally,
        simpleBackground: true,
        blurred: Blured.veryLittle
    ),
    'darkgem': Author(
        name: 'darkgem',
        looks: Looks.shaded,
        style: Style.drawing,
        detailed: Detailed.smallDetails,
        blurred: Blured.veryLittle
    ),
    'chunie': Author(
        name: 'Chunie',
        looks: Looks.shaded,
        style: Style.drawing,
        detailed: Detailed.smallDetails,
        blurred: Blured.veryLittle,
        rubber: true
    ),
    'blotch': Author(
        name: 'blotch',
        looks: Looks.almostRealistic,
        style: Style.painting,
        detailed: Detailed.smallDetails,
        simpleBackground: true
    ),
    'ventkazemaru': Author(
        name: 'ventkazemaru',
        looks: Looks.coloredSketch,
        style: Style.drawing,
        stable: true,
        sharpLine: true
    ),
    'zackary911': Author(
        name: 'braeburned',
        looks: Looks.coloredSketchShaded,
        style: Style.cartoon,
        sharpLine: true,
        hasText: true,
        hasSignature: true
    ),
    'zourik': Author(
        name: 'zourik',
        looks: Looks.coloredSketchShaded,
        style: Style.cartoon,
        detailed: Detailed.generally,
        sharpLine: true,
        hasText: true,
        hasSignature: true,
        comics: true,
    ),
    'orf': Author(
        name: 'orf',
        looks: Looks.coloredSketch,
        style: Style.cartoonDrawing,
        sharpLine: true,
        simpleBackground: true
    ),
    'k-9': Author(
        name: 'orf',
        looks: Looks.coloredSketch,
        style: Style.cartoonDrawing,
        sharpLine: true
    ),
    'adelaherz': Author(
        name: 'adelaherz',
        looks: Looks.coloredSketchShaded,
        style: Style.drawing,
        detailed: Detailed.smallDetails
    ),
    'alibi-cami': Author(
        name: 'alibi-cami',
        looks: Looks.coloredSketchShaded,
        style: Style.cartoonDrawing,
        sharpLine: true
    ),
  };
}

class Author{
  String name;
  Blured? blurred = Blured.none;
  bool? rubber = false;
  Looks looks;
  bool? asian = false;
  Style style;
  bool? stable = true;
  bool? sharpLine = false;
  Detailed? detailed = Detailed.normal;
  bool? simpleBackground = false;
  bool? hasSignature = false;
  bool? hasText = false;
  bool? comics = false;

  Author({
    required this.name,
    this.blurred,
    this.rubber,
    required this.looks,
    this.asian,
    required this.style,
    this.stable,
    this.sharpLine,
    this.detailed,
    this.simpleBackground,
    this.hasSignature,
    this.hasText,
    this.comics
  });
}

enum Blured {
  none,
  veryLittle,
  slightly,
  strongly,
  hard
}

enum Looks {
  sketch,
  coloredSketch,
  coloredSketchShaded,
  shaded,
  almostRealistic,
  realistic
}

enum Style {
  dontUseThis,
  cartoon,
  cartoonDrawing,
  drawing,
  painting,
  outlineRealistic,
  realistic,
}

enum Detailed {
  normal,
  generally,
  smallDetails
}