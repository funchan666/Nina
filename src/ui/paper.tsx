import React from 'react';
import {
  I18nManager, Image, Keyboard, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import type {ScrollViewProps, StyleProp, TextInputProps, TextStyle, ViewStyle} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {useFlow} from '../navigation';
import {glyphs, grounds} from './artwork';
import {ActionBand, useWindowLayout} from './geometry';

export const colors = {
  paper: '#F5F0E5',
  ink: '#182620',
  grip: '#DFF075',
  sage: '#DDE4D5',
  muted: '#475449',
  oxide: '#963825',
};
const heading = 'BarlowCondensed-Bold';
const body = 'Barlow-Regular';
const bold = 'Barlow-SemiBold';

export type GlyphName = keyof typeof glyphs;
type Ground = keyof typeof grounds;

export const layout = StyleSheet.create({
  fill: {flex: 1},
  stack: {gap: 8},
  row: {flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap'},
  split: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10},
  section: {backgroundColor: colors.paper, padding: 16, gap: 8, borderRadius: 16},
  paper: {backgroundColor: colors.paper},
  ink: {backgroundColor: colors.ink},
});

export function Copy({children, size = 'body', color = colors.ink, style, limit, header}: {
  children: React.ReactNode;
  size?: 'title' | 'heading' | 'card' | 'body' | 'label' | 'caption';
  color?: string;
  style?: StyleProp<TextStyle>;
  limit?: number;
  header?: boolean;
}) {
  return <Text accessibilityRole={header ? 'header' : undefined} numberOfLines={limit}
    style={[styles[size], {color}, style]}>{children}</Text>;
}

export function Glyph({name, size = 24, color = colors.ink}: {name: GlyphName; size?: number; color?: string}) {
  return <Image accessible={false} source={glyphs[name]} resizeMode="contain"
    style={{width: size, height: size, tintColor: color,
      transform: name === 'back' && I18nManager.isRTL ? [{scaleX: -1}] : undefined}} />;
}

export function Backdrop({image}: {image: Ground}) {
  return <Image accessible={false} resizeMode="cover" pointerEvents="none" source={grounds[image]}
    style={[StyleSheet.absoluteFill, styles.background]} />;
}

type Tone = 'primary' | 'paper' | 'ink' | 'plain' | 'danger';
const background: Record<Tone, string> = {
  primary: colors.grip, paper: colors.paper, ink: colors.ink, plain: 'transparent', danger: colors.oxide,
};

export function Action({title, icon, action, tone = 'primary', disabled, selected}: {
  title: string;
  icon?: GlyphName;
  action: () => void;
  tone?: Tone;
  disabled?: boolean;
  selected?: boolean;
}) {
  const color = tone === 'ink' || tone === 'danger' ? colors.paper : colors.ink;
  return (
    <Pressable accessibilityRole="button" accessibilityState={{disabled, selected}} disabled={disabled} onPress={action}
      style={({pressed}) => [styles.button, {backgroundColor: background[tone], opacity: disabled ? 0.46 : pressed ? 0.74 : 1}]}>
      {icon && <Glyph name={icon} color={color} size={21} />}
      <Copy size="label" color={color} style={styles.buttonText}>{title}</Copy>
    </Pressable>
  );
}

export function IconAction({title, icon, action, color = colors.ink, fill = 'transparent', disabled}: {
  title: string;
  icon: GlyphName;
  action: () => void;
  color?: string;
  fill?: string;
  disabled?: boolean;
}) {
  return <Pressable onPress={action} disabled={disabled} accessibilityRole="button" accessibilityLabel={title}
    accessibilityState={{disabled}}
    style={({pressed}) => [styles.iconButton, {backgroundColor: fill, opacity: disabled ? 0.46 : pressed ? 0.74 : 1}]}>
    <Glyph name={icon} color={color} />
  </Pressable>;
}

export function Row({title, detail, icon, children, action, disabled}: {
  title: string; detail?: string; icon?: GlyphName; children?: React.ReactNode; action: () => void; disabled?: boolean;
}) {
  return <Pressable accessibilityRole="button" accessibilityState={{disabled}} onPress={action} disabled={disabled}
    style={({pressed}) => [styles.rowButton, {opacity: disabled ? 0.46 : pressed ? 0.74 : 1}]}>
    {children}
    {icon && <Glyph name={icon} size={26} />}
    <View style={layout.fill}>
      <Copy size="label">{title}</Copy>
      {detail ? <Copy color={colors.muted}>{detail}</Copy> : null}
    </View>
  </Pressable>;
}

export function Empty({icon, title, note}: {icon: GlyphName; title: string; note?: string}) {
  return <View style={styles.empty}>
    <Glyph name={icon} size={49} />
    <Copy size="heading" header>{title}</Copy>
    {note ? <Copy color={colors.muted}>{note}</Copy> : null}
  </View>;
}

export function Notice({children, error}: {children: React.ReactNode; error?: boolean}) {
  return <View accessibilityLiveRegion={error ? 'assertive' : 'polite'} style={styles.notice}>
    <Copy size="label" color={error ? colors.oxide : colors.ink}>{children}</Copy>
  </View>;
}

export function Choices<T extends string>({values, value, onChange, label}: {
  values: readonly T[]; value?: T; onChange(value: T): void; label: (value: T) => string;
}) {
  return <ScrollView horizontal showsHorizontalScrollIndicator={false} keyboardShouldPersistTaps="handled" directionalLockEnabled>
    <View style={styles.choices}>
      {values.map(item => <Action key={item} title={label(item)} selected={item === value}
        tone={item === value ? 'ink' : 'paper'} action={() => onChange(item)} />)}
    </View>
  </ScrollView>;
}

export function Check({title, value, toggle}: {title: string; value: boolean; toggle(): void}) {
  return <Pressable accessibilityRole="checkbox" accessibilityState={{checked: value}} onPress={toggle} style={styles.check}>
    <View style={[styles.checkbox, {backgroundColor: value ? colors.grip : colors.sage}]}>
      {value && <Glyph name="check" size={20} />}
    </View>
    <Copy size="label" style={layout.fill}>{title}</Copy>
  </Pressable>;
}

export function Field({label, multiline, ...options}: TextInputProps & {label: string}) {
  return <View style={styles.field}>
    <Copy size="label">{label}</Copy>
    <TextInput accessibilityLabel={label} placeholderTextColor={colors.muted} returnKeyType={multiline ? 'default' : 'done'}
      multiline={multiline} selectionColor={colors.oxide} {...options}
      style={[styles.input, multiline && styles.multiline, options.style]} />
  </View>;
}

export function PageHeading({title, large, children}: {title: string; large?: boolean; children?: React.ReactNode}) {
  return <View style={[layout.split, styles.headingRow]}>
    <Copy size={large ? 'title' : 'heading'} header style={styles.pageTitle}>{title}</Copy>
    {children}
  </View>;
}

export function Screen({title, ground, root = false, editing = false, action, children, scrollRef, onContentSizeChange}: {
  title: string;
  ground: Ground;
  root?: boolean;
  editing?: boolean;
  action?: React.ReactNode;
  children: React.ReactNode;
  scrollRef?: React.RefObject<ScrollView | null>;
  onContentSizeChange?: ScrollViewProps['onContentSizeChange'];
}) {
  const flow = useFlow();
  const safe = useSafeAreaInsets();
  const {margins} = useWindowLayout();
  return <View style={styles.canvas}>
    <Backdrop image={ground} />
    <View style={layout.fill}>
      {!root && <ActionBand edge="top">
        <View style={styles.navBar}>
          <IconAction title="Back" icon="back" fill={colors.paper} action={flow.back} />
          {editing && <Action title="Done typing" tone="paper" icon="check" action={Keyboard.dismiss} />}
        </View>
      </ActionBand>}
      <ScrollView
        ref={scrollRef}
        onContentSizeChange={onContentSizeChange}
        style={layout.fill}
        contentInsetAdjustmentBehavior="never"
        automaticallyAdjustContentInsets={false}
        automaticallyAdjustsScrollIndicatorInsets={false}
        automaticallyAdjustKeyboardInsets={flow.visible && editing}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode={editing ? 'interactive' : 'none'}
        contentContainerStyle={{
          paddingLeft: Math.max(margins.left, safe.left), paddingRight: Math.max(margins.right, safe.right),
          paddingBottom: root ? 28 : Math.max(28, safe.bottom + 12),
        }}
      >
        <View style={[styles.scrollContent, root && {paddingTop: safe.top + 8}]}>
          <PageHeading title={title} large={root}>{action}</PageHeading>
          {children}
        </View>
      </ScrollView>
    </View>
  </View>;
}

const styles = StyleSheet.create({
  title: {fontFamily: heading, fontSize: 44},
  heading: {fontFamily: heading, fontSize: 32},
  card: {fontFamily: heading, fontSize: 26},
  body: {fontFamily: body, fontSize: 17},
  label: {fontFamily: bold, fontSize: 16},
  caption: {fontFamily: bold, fontSize: 14},
  canvas: {flex: 1, backgroundColor: colors.sage},
  background: {width: '100%', height: '100%', opacity: 0.24},
  button: {minHeight: 48, minWidth: 44, paddingHorizontal: 15, paddingVertical: 10, borderRadius: 12, flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', gap: 8, maxWidth: '100%'},
  buttonText: {flexShrink: 1},
  rowButton: {minHeight: 64, alignSelf: 'stretch', flexDirection: 'row', alignItems: 'center', backgroundColor: colors.paper, gap: 12, padding: 15, borderRadius: 16},
  iconButton: {width: 46, height: 46, borderRadius: 12, alignItems: 'center', justifyContent: 'center'},
  empty: {alignSelf: 'stretch', backgroundColor: colors.paper, gap: 10, padding: 20, borderRadius: 18},
  notice: {padding: 14, backgroundColor: colors.paper, borderRadius: 12},
  choices: {flexDirection: 'row', gap: 5},
  check: {minHeight: 44, flexDirection: 'row', alignItems: 'center', gap: 9},
  checkbox: {width: 32, height: 32, alignItems: 'center', justifyContent: 'center'},
  field: {gap: 5, minWidth: 0},
  input: {minHeight: 50, paddingVertical: 12, paddingHorizontal: 14, borderRadius: 12, backgroundColor: colors.paper, fontFamily: body, fontSize: 17, color: colors.ink},
  multiline: {minHeight: 90, textAlignVertical: 'top'},
  navBar: {minHeight: 54, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 5},
  headingRow: {flexWrap: 'wrap'},
  pageTitle: {flexShrink: 1},
  scrollContent: {width: '100%', maxWidth: 730, alignSelf: 'center', gap: 17, paddingTop: 8},
});
