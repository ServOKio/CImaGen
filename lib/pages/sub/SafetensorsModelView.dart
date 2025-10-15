import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:humanize_duration/humanize_duration.dart';

import '../../components/Animations.dart';
import '../../components/ImageInfo.dart';

class SafetensorsModelView extends StatefulWidget {
  final Map<String, dynamic> data;
  const SafetensorsModelView(this.data, {super.key});

  @override
  State<SafetensorsModelView> createState() => _SafetensorsModelViewState();
}

class _SafetensorsModelViewState extends State<SafetensorsModelView> {
  bool loaded = false;
  String? error;
  
  List<String> allowedKeys = [];
  Map<String, int>? ss_tag_frequency = {};
  
  void initState(){
    try{
      processData().then((_) => setState(() {
        allowedKeys = widget.data.keys.where((el) => el != '__metadata__').toList();
        loaded = true;
      }));
      setState(() {
        allowedKeys = widget.data.keys.where((el) => el != '__metadata__').toList();
        loaded = true;
      });
    } catch(e, stack){
      setState(() {
        error = e.toString()+stack.toString();
      });
    }
  }

  Future<void> processData() async{
    Map<String, dynamic> meta = widget.data['__metadata__'];
    if(meta['ss_tag_frequency'] != null){
      Map<String, dynamic> d = await jsonDecode(meta['ss_tag_frequency']) as Map<String, dynamic>;
      ss_tag_frequency = Map<String, int>.from(d[d.keys.first]);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
      title: Center(child: ShowUp(
        delay: 100,
        child: Text('Safetensors Model Viewer', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
      )),
    );

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        backgroundColor: Color(0xff141517),
        body: SafeArea(
            child: error == null ? Row(
              children: [
                Left(),
                Expanded(
                  child: Text('fdf')
                ),
                Right()
              ],
            ) : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 50, color: Colors.redAccent),
                  Gap(4),
                  Text('Oops, looks like there was an error...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SelectableText('E: $error', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
        )
    );
  }

  Widget Left(){
    Map<String, dynamic> meta = widget.data['__metadata__'];
    return Container(
      padding: const EdgeInsets.all(6),
      color: Color(0xff1b1c20),
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
                decoration: const BoxDecoration(
                    color: Color(0xff303030),
                    borderRadius: BorderRadius.all(Radius.circular(4))
                ),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Specification', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Column(
                          children: [
                            // https://github.com/Stability-AI/ModelSpec
                            InfoBox(one: 'Specification version', two: meta['modelspec.sai_model_spec']),
                            InfoBox(one: 'Architecture', two: meta['modelspec.architecture']),
                            InfoBox(one: 'Implementation', two: meta['modelspec.implementation']),
                            InfoBox(one: 'Title', two: meta['modelspec.title']),
                            if(meta['modelspec.description'] != null) InfoBox(one: 'description', two: meta['modelspec.description']),
                            if(meta['modelspec.author'] != null) InfoBox(one: 'Author', two: meta['modelspec.author']),
                            if(meta['modelspec.date'] != null) InfoBox(one: 'Date', two: meta['modelspec.date']),
                            if(meta['modelspec.hash_sha256'] != null) InfoBox(one: 'SHA256 Hach', two: meta['modelspec.hash_sha256']),
                            if(meta['modelspec.implementation_version'] != null) InfoBox(one: 'Implementation Version', two: meta['modelspec.implementation _version']),
                            if(meta['modelspec.license'] != null) InfoBox(one: 'License', two: meta['modelspec.license']),
                            if(meta['modelspec.usage_hint'] != null) InfoBox(one: 'Usage Hint', two: meta['modelspec.usage_hint']),
                            if(meta['modelspec.thumbnail'] != null) InfoBox(one: 'Thumbnail', two: meta['modelspec.thumbnail']),
                            if(meta['modelspec.tags'] != null) InfoBox(one: 'Tags', two: meta['modelspec.tags']),
                            if(meta['modelspec.merged_from'] != null) InfoBox(one: 'Merged from', two: meta['modelspec.merged_from']),
                          ],
                        )
                      ],
                    )
                )
            ),
            Gap(8),
            Container(
                decoration: const BoxDecoration(
                    color: Color(0xff303030),
                    borderRadius: BorderRadius.all(Radius.circular(4))
                ),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category-Specific Keys', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Column(
                          children: [
                            // https://github.com/Stability-AI/ModelSpec
                            if(meta['modelspec.resolution'] != null) InfoBox(one: 'Resolution', two: meta['modelspec.resolution']),
                            if(meta['modelspec.trigger_phrase'] != null) InfoBox(one: 'Trigger Phrase', two: meta['modelspec.trigger_phrase']),
                            if(meta['modelspec.prediction_type'] != null) InfoBox(one: 'Prediction Type', two: meta['modelspec.prediction_type']),
                            if(meta['modelspec.timestep_range'] != null) InfoBox(one: 'Timestep Range', two: meta['modelspec.timestep_range']),
                            if(meta['modelspec.encoder_layer'] != null) InfoBox(one: 'Encoder Layer', two: meta['modelspec.encoder_layer']),
                            if(meta['modelspec.preprocessor'] != null) InfoBox(one: 'Preprocessor', two: meta['modelspec.preprocessor']),
                            if(meta['modelspec.is_negative_embedding'] != null) InfoBox(one: 'is negative embedding', two: meta['modelspec.is_negative_embedding']),
                            if(meta['modelspec.unet_dtype'] != null) InfoBox(one: 'UNET dtype', two: meta['modelspec.unet_dtype']),
                            if(meta['modelspec.vae_dtype'] != null) InfoBox(one: 'VAE dtype', two: meta['modelspec.vae_dtype']),
                          ],
                        )
                      ],
                    )
                )
            ),
            Gap(8),
            Container(
                decoration: const BoxDecoration(
                    color: Color(0xff303030),
                    borderRadius: BorderRadius.all(Radius.circular(4))
                ),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Text-Prediction Models', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Column(
                          children: [
                            // https://github.com/Stability-AI/ModelSpec
                            if(meta['modelspec.data_format'] != null) InfoBox(one: 'Data Format', two: meta['modelspec.data_format']),
                            if(meta['modelspec.format_type'] != null) InfoBox(one: 'Format Type', two: meta['modelspec.format_type']),
                            if(meta['modelspec.language'] != null) InfoBox(one: 'Language', two: meta['modelspec.language']),
                            if(meta['modelspec.format_template'] != null) InfoBox(one: 'Format_template', two: meta['modelspec.format_template']),
                          ],
                        )
                      ],
                    )
                )
            ),
            Gap(8),
            Container(
                decoration: const BoxDecoration(
                    color: Color(0xff303030),
                    borderRadius: BorderRadius.all(Radius.circular(4))
                ),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Metadata/Hyperparameters', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Column(
                          children: [
                            if(meta['ss_batch_size_per_device'] != null) InfoBox(one: 'Batch Size Per Device', two: meta['ss_batch_size_per_device']),
                            if(meta['ss_bucket_info'] != null) InfoBox(one: 'Bucket Info', two: meta['ss_bucket_info']),
                            if(meta['ss_bucket_no_upscale'] != null) InfoBox(one: 'Bucket No Upscale', two: meta['ss_bucket_no_upscale']),
                            if(meta['ss_sd_model_name'] != null) InfoBox(one: 'Model Name', two: meta['ss_sd_model_name']),
                            if(meta['ss_clip_skip'] != null) InfoBox(one: 'Clip Skip', two: meta['ss_clip_skip']),
                            if(meta['ss_num_train_images'] != null) InfoBox(one: 'Number of Training Images', two: meta['ss_num_train_images']),
                            if(meta['ss_tag_frequency'] != null) InfoBox(one: 'Tag Frequency', two: '${ss_tag_frequency!.length.toString()} tags'),
                            if(meta['ss_epoch'] != null) InfoBox(one: 'Epochs', two: meta['ss_epoch']),
                            if(meta['ss_face_crop_aug_range'] != null) InfoBox(one: 'Face Crop Augmentation Range', two: meta['ss_face_crop_aug_range']),
                            if(meta['ss_full_fp16'] != null) InfoBox(one: 'Full FP16', two: meta['ss_full_fp16']),
                            if(meta['ss_gradient_accumulation_steps'] != null) InfoBox(one: 'Gradient Accumulation Steps', two: meta['ss_gradient_accumulation_steps']),
                            if(meta['ss_gradient_checkpointing'] != null) InfoBox(one: 'Gradient Checkpointing', two: meta['ss_gradient_checkpointing']),
                            if(meta['ss_learning_rate'] != null) InfoBox(one: 'Learning Rate', two: meta['ss_learning_rate']),
                            if(meta['ss_lowram'] != null) InfoBox(one: 'Low RAM', two: meta['ss_lowram']),
                            if(meta['ss_lr_scheduler'] != null) InfoBox(one: 'Learning Rate Scheduler', two: meta['ss_lr_scheduler']),
                            if(meta['ss_lr_warmup_steps'] != null) InfoBox(one: 'Learning Rate Warmup Steps', two: meta['ss_lr_warmup_steps']),
                            if(meta['ss_max_grad_norm'] != null) InfoBox(one: 'Max Gradient Norm', two: meta['ss_max_grad_norm']),
                            if(meta['ss_max_token_length'] != null) InfoBox(one: 'Max Token Length', two: meta['ss_max_token_length']),
                            if(meta['ss_max_train_steps'] != null) InfoBox(one: 'Max Training Steps', two: meta['ss_max_train_steps']),
                            if(meta['ss_min_snr_gamma'] != null) InfoBox(one: 'Min SNR Gamma', two: meta['ss_min_snr_gamma']),
                            if(meta['ss_mixed_precision'] != null) InfoBox(one: 'Mixed Precision', two: meta['ss_mixed_precision']),
                            if(meta['ss_network_alpha'] != null) InfoBox(one: 'Network Alpha', two: meta['ss_network_alpha']),
                            if(meta['ss_network_dim'] != null) InfoBox(one: 'Network Dimension', two: meta['ss_network_dim']),
                            if(meta['ss_network_module'] != null) InfoBox(one: 'Network Module', two: meta['ss_network_module']),
                            if(meta['ss_new_sd_model_hash'] != null) InfoBox(one: 'New SD Model Hash', two: meta['ss_new_sd_model_hash']),
                            if(meta['ss_noise_offset'] != null) InfoBox(one: 'Noise Offset', two: meta['ss_noise_offset']),
                            if(meta['ss_num_batches_per_epoch'] != null) InfoBox(one: 'Number of Batches per Epoch', two: meta['ss_num_batches_per_epoch']),
                            if(meta['ss_cache_latents'] != null) InfoBox(one: 'Cache Latents', two: meta['ss_cache_latents']),
                            if(meta['ss_caption_dropout_every_n_epochs'] != null) InfoBox(one: 'Caption Dropout Every N Epochs', two: meta['ss_caption_dropout_every_n_epochs']),
                            if(meta['ss_caption_dropout_rate'] != null) InfoBox(one: 'Caption Dropout Rate', two: meta['ss_caption_dropout_rate']),
                            if(meta['ss_caption_tag_dropout_rate'] != null) InfoBox(one: 'Caption Tag Dropout Rate', two: meta['ss_caption_tag_dropout_rate']),
                            if(meta['ss_dataset_dirs'] != null) InfoBox(one: 'Dataset Directories', two: meta['ss_dataset_dirs']),
                            if(meta['ss_num_epochs'] != null) InfoBox(one: 'Number of Epochs', two: meta['ss_num_epochs']),
                            if(meta['ss_num_reg_images'] != null) InfoBox(one: 'Number of Regression Images', two: meta['ss_num_reg_images']),
                            if(meta['ss_optimizer'] != null) InfoBox(one: 'Optimizer', two: meta['ss_optimizer']),
                            if(meta['ss_output_name'] != null) InfoBox(one: 'Output Name', two: meta['ss_output_name']),
                            if(meta['ss_prior_loss_weight'] != null) InfoBox(one: 'Prior Loss Weight', two: meta['ss_prior_loss_weight']),
                            if(meta['ss_random_crop'] != null) InfoBox(one: 'Random Crop', two: meta['ss_random_crop']),
                            if(meta['ss_reg_dataset_dirs'] != null) InfoBox(one: 'Dataset Directories', two: meta['ss_reg_dataset_dirs']),
                            if(meta['ss_resolution'] != null) InfoBox(one: 'Resolution', two: meta['ss_resolution']),
                            if(meta['ss_shuffle_caption'] != null) InfoBox(one: 'Shuffle Caption', two: meta['ss_shuffle_caption']),
                            if(meta['ss_sd_model_hash'] != null) InfoBox(one: 'SD Model Hash', two: meta['ss_sd_model_hash']),
                            if(meta['ss_sd_scripts_commit_hash'] != null) InfoBox(one: 'SD Scripts Commit Hash', two: meta['ss_sd_scripts_commit_hash']),
                            if(meta['ss_seed'] != null) InfoBox(one: 'Seed', two: meta['ss_seed']),
                            if(meta['ss_session_id'] != null) InfoBox(one: 'Session ID', two: meta['ss_session_id']),
                            if(meta['ss_text_encoder_lr'] != null) InfoBox(one: 'Text Encoder Learning Rate', two: meta['ss_text_encoder_lr']),
                            if(meta['ss_total_batch_size'] != null) InfoBox(one: 'Total Batch Size', two: meta['ss_total_batch_size']),
                            if(meta['ss_unet_lr'] != null) InfoBox(one: 'UNet Learning Rate', two: meta['ss_unet_lr']),
                            if(meta['ss_v2'] != null) InfoBox(one: 'Version 2', two: meta['ss_v2']),
                            if(meta['sshs_legacy_hash'] != null) InfoBox(one: 'SSHS Legacy Hash', two: meta['sshs_legacy_hash']),

                            if(meta['ss_training_comment'] != null) InfoBox(one: 'Training Comment', two: meta['ss_training_comment']),
                            if(meta['ss_training_started_at'] != null) InfoBox(one: 'Training Started At', two: meta['ss_training_started_at']),
                            if(meta['ss_training_finished_at'] != null) InfoBox(one: 'Training Finished At', two: meta['ss_training_finished_at']),
                            if(meta['ss_training_finished_at'] != null && meta['ss_training_finished_at'] != null) InfoBox(one: 'Training Time Total', two: humanizeDuration(Duration(seconds: (double.parse(meta['ss_training_finished_at']) - double.parse(meta['ss_training_started_at'])).toInt()))),
                          ],
                        )
                      ],
                    )
                )
            ),
          ],
        ),

      ),
    );
  }

  Color getColor(int index){
    List<Color> c = [
      const Color(0xffea4b49),
      const Color(0xfff88749),
      const Color(0xfff8be46),
      const Color(0xff89c54d),
      const Color(0xff48bff9),
      const Color(0xff5b93fd),
      const Color(0xff9c6efb)
    ];
    return c[index % c.length];
  }

  Widget Right(){
    return Container(
      color: Color(0xff1b1c20),
      width: 300,
      child: Text('fdf')
      // ListView.separated(
      //   shrinkWrap: true,
      //   itemCount: allowedKeys.length,
      //   itemBuilder: (context, index) {
      //     var it = widget.data[allowedKeys[index]];
      //     return Container(
      //       padding: const EdgeInsets.all(7),
      //       decoration: BoxDecoration(
      //           borderRadius: BorderRadius.circular(14),
      //           color: Colors.white10
      //       ),
      //       child: Column(
      //         children: [
      //           InfoBox(one: 'key', two: allowedKeys[index]),
      //           InfoBox(one: 'dtype', two: it['dtype']),
      //           InfoBox(one: 'shape', two: it['shape'].join(', ')),
      //           InfoBox(one: 'data offsets', two: it['data_offsets'].join(', '))
      //         ],
      //       ),
      //     );
      //   }, separatorBuilder: (BuildContext context, int index) => const Divider(height: 14),
      // ),
    );
  }
}

enum SafetensorsModelType {
  modelMerge,
  lora
}

String safetensorsModelTypeToString(SafetensorsModelType type){
  return {
    SafetensorsModelType.modelMerge: 'Moder merge',
    SafetensorsModelType.lora: 'Lora',
  }[type] ?? 'Unknown*';
}

class SafetensorsModel {
  final dynamic data;
  final SafetensorsModelType type;
  const SafetensorsModel({
    required this.type,
    required this.data
  });
}