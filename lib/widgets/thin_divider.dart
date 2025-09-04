import 'package:fluent_ui/fluent_ui.dart';

class ThinDivider extends StatelessWidget {
  const ThinDivider({super.key, this.margin});
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: 1,
      color: const Color(0x14000000),
    );
  }
}

