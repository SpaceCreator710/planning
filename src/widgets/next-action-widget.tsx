import { HStack, Image, Spacer, Text, VStack } from '@expo/ui/swift-ui';
import { containerBackground, font, foregroundStyle, lineLimit, padding, widgetURL } from '@expo/ui/swift-ui/modifiers';
import { createWidget, type WidgetEnvironment } from 'expo-widgets';

export interface NextActionWidgetProps {
  title: string;
  time: string;
  minutes: number;
  progress: number;
  accent: string;
  complete: boolean;
}

function NextActionWidget(props: NextActionWidgetProps, environment: WidgetEnvironment) {
  'widget';
  const secondary = environment.colorScheme === 'dark' ? '#C9C9CE' : '#696970';
  if (environment.widgetFamily === 'accessoryInline') {
    return <Text>{props.complete ? 'Day complete' : `${props.time} · ${props.title}`}</Text>;
  }
  if (environment.widgetFamily === 'accessoryCircular') {
    return (
      <VStack alignment="center" spacing={2} modifiers={[widgetURL('aiplanyourday://today')]}>
        <Image systemName={props.complete ? 'checkmark.circle.fill' : 'link'} size={19} color={props.accent} />
        <Text modifiers={[font({ weight: 'bold', size: 11 })]}>{props.complete ? 'Done' : `${props.progress}%`}</Text>
      </VStack>
    );
  }
  if (environment.widgetFamily === 'accessoryRectangular') {
    return (
      <HStack spacing={8} modifiers={[widgetURL('aiplanyourday://today')]}>
        <Image systemName={props.complete ? 'checkmark.circle.fill' : 'play.circle.fill'} size={24} color={props.accent} />
        <VStack alignment="leading" spacing={1}>
          <Text modifiers={[font({ weight: 'bold', size: 13 }), lineLimit(1)]}>{props.complete ? 'Day complete' : props.title}</Text>
          <Text modifiers={[font({ size: 11 }), foregroundStyle(secondary)]}>{props.complete ? `${props.progress}% finished` : `${props.time} · ${props.minutes} min`}</Text>
        </VStack>
      </HStack>
    );
  }
  return (
    <VStack
      alignment="leading"
      spacing={7}
      modifiers={[
        padding({ all: 14 }),
        containerBackground(environment.colorScheme === 'dark' ? '#17171A' : '#FFFFFF', 'widget'),
        widgetURL('aiplanyourday://today'),
      ]}>
      <HStack spacing={6}>
        <Image systemName="link" size={16} color={props.accent} />
        <Text modifiers={[font({ weight: 'bold', size: 12 }), foregroundStyle(props.accent)]}>NEXT ACTION</Text>
        <Spacer />
        <Text modifiers={[font({ weight: 'semibold', size: 12 }), foregroundStyle(secondary)]}>{props.progress}%</Text>
      </HStack>
      <Text modifiers={[font({ weight: 'bold', size: 17 }), lineLimit(2)]}>{props.complete ? 'Your day chain is complete' : props.title}</Text>
      <Text modifiers={[font({ size: 12 }), foregroundStyle(secondary)]}>{props.complete ? 'Take a breath and close the loop.' : `${props.time} · ${props.minutes} minutes`}</Text>
    </VStack>
  );
}

export default createWidget<NextActionWidgetProps>('NextActionWidget', NextActionWidget);
