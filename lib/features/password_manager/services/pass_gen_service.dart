import 'dart:math';

/// Cryptographically secure Password & Passphrase Generator service
/// inspired by pass-gen (EFF Diceware, CSPRNG, Bit Entropy & GPU Crack Time Estimator).
class PassGenService {
  static final Random _secureRandom = Random.secure();

  // Character sets
  static const String upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowerChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String numChars = '0123456789';
  static const String symbolChars = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

  static final RegExp _ambiguousRegex = RegExp(r'[l1IO0oQS5Z2]');

  // EFF Diceware wordlist (~500 curated clean memorable words)
  static const List<String> effWords = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
    'accent', 'access', 'account', 'accurate', 'achieve', 'acid', 'acoustic', 'acquire',
    'across', 'action', 'active', 'actor', 'actual', 'adapt', 'addiction', 'address',
    'adjust', 'admire', 'admit', 'adobe', 'adopt', 'adult', 'advance', 'advice',
    'aerobic', 'afford', 'afraid', 'again', 'agent', 'agree', 'ahead', 'aim',
    'airport', 'aisle', 'alarm', 'album', 'alcohol', 'alert', 'alien', 'all',
    'alley', 'allow', 'almost', 'alone', 'alpha', 'already', 'also', 'alter',
    'always', 'amateur', 'amazing', 'amber', 'ambient', 'ambition', 'amount', 'anchor',
    'ancient', 'angle', 'angry', 'animal', 'ankle', 'announce', 'annual', 'another',
    'answer', 'antenna', 'antique', 'anxiety', 'any', 'apart', 'apology', 'apparel',
    'appear', 'apple', 'approve', 'april', 'arch', 'arctic', 'area', 'arena',
    'argue', 'arise', 'arm', 'armed', 'armor', 'army', 'around', 'arrange',
    'arrest', 'arrive', 'arrow', 'art', 'artefact', 'artist', 'artwork', 'ask',
    'aspect', 'assault', 'asset', 'assist', 'assume', 'asthma', 'athlete', 'atom',
    'attack', 'attend', 'attitude', 'attract', 'auction', 'audit', 'august', 'aunt',
    'auto', 'author', 'automate', 'autumn', 'average', 'avocado', 'avoid', 'awake',
    'award', 'aware', 'awesome', 'awful', 'awkward', 'axis', 'baby', 'bachelor',
    'bacon', 'badge', 'bag', 'balance', 'balcony', 'ball', 'bamboo', 'banana',
    'banner', 'bar', 'barely', 'bargain', 'barrel', 'base', 'basic', 'basket',
    'battle', 'beach', 'beacon', 'beam', 'bean', 'beauty', 'because', 'become',
    'beef', 'before', 'begin', 'behave', 'behind', 'believe', 'below', 'belt',
    'bench', 'benefit', 'best', 'betray', 'better', 'between', 'beyond', 'bicycle',
    'bid', 'bike', 'bind', 'biology', 'bird', 'birth', 'bitter', 'black',
    'blade', 'blame', 'blanket', 'blast', 'blaze', 'blend', 'bless', 'blind',
    'blood', 'blossom', 'blouse', 'blue', 'blur', 'blush', 'board', 'boat',
    'body', 'boil', 'bolt', 'bomb', 'bond', 'bone', 'bonus', 'book',
    'boost', 'border', 'boring', 'borrow', 'boss', 'bottom', 'bounce', 'box',
    'brain', 'brand', 'brass', 'brave', 'bread', 'breeze', 'brick', 'bridge',
    'brief', 'bright', 'bring', 'brisk', 'broccoli', 'broken', 'bronze', 'broom',
    'brother', 'brown', 'brush', 'bubble', 'buddy', 'budget', 'buffer', 'bug',
    'build', 'bullet', 'bundle', 'bunker', 'burden', 'burger', 'burst', 'bus',
    'business', 'busy', 'butter', 'buyer', 'buzz', 'cabbage', 'cabin', 'cable',
    'cactus', 'cage', 'cake', 'call', 'calm', 'camera', 'camp', 'can',
    'canal', 'cancel', 'candy', 'cannon', 'canoe', 'canvas', 'canyon', 'capable',
    'capital', 'captain', 'car', 'carbon', 'card', 'cargo', 'carpet', 'carry',
    'cart', 'case', 'casino', 'castle', 'casual', 'cat', 'catalog',
    'catch', 'category', 'cattle', 'cause', 'caution', 'cave', 'ceiling', 'celery',
    'cement', 'census', 'center', 'central', 'century', 'cereal', 'certain', 'chair',
    'chalk', 'champion', 'change', 'chaos', 'chapter', 'charge', 'chase', 'chat',
    'cheap', 'check', 'cheese', 'chef', 'cherry', 'chest', 'chicken', 'chief',
    'child', 'chimney', 'choice', 'choose', 'chronic', 'chuckle', 'chunk', 'churn',
    'cider', 'cigar', 'cinema', 'circle', 'citizen', 'city', 'civil', 'claim',
    'clap', 'clarity', 'clasp', 'class', 'classic', 'clean', 'clear', 'clever',
    'click', 'client', 'cliff', 'climb', 'clinic', 'clip', 'clock', 'clog',
    'close', 'cloth', 'cloud', 'clown', 'club', 'clump', 'cluster', 'clutch',
    'coach', 'coast', 'coconut', 'code', 'coffee', 'coil', 'coin', 'collect',
    'color', 'column', 'combine', 'come', 'comfort', 'comic', 'common', 'company',
    'concert', 'conduct', 'confirm', 'congress', 'connect', 'consider', 'control', 'convince',
    'cook', 'cool', 'copper', 'copy', 'coral', 'core', 'corn', 'correct',
    'cost', 'cotton', 'couch', 'country', 'couple', 'courage', 'course', 'cousin',
    'cover', 'coyote', 'crack', 'cradle', 'craft', 'cram', 'crane', 'crash',
    'crater', 'crawl', 'crazy', 'cream', 'credit', 'creek', 'crew', 'cricket',
    'crime', 'crisp', 'critic', 'crop', 'cross', 'crouch', 'crowd', 'crucial',
    'cruel', 'cruise', 'crumble', 'crunch', 'crush', 'cry', 'crystal', 'cube',
    'culture', 'cup', 'cupboard', 'curious', 'current', 'curtain', 'curve', 'cushion',
    'custom', 'cute', 'cycle', 'dad', 'damage', 'damp', 'dance', 'danger',
    'daring', 'dark', 'dash', 'date', 'daughter', 'dawn', 'day', 'deal',
    'debate', 'debris', 'decade', 'december', 'decide', 'decline', 'decor', 'decrease',
    'deep', 'deer', 'defense', 'define', 'defy', 'degree', 'delay', 'deliver',
    'demand', 'demise', 'denial', 'dentist', 'deposit', 'depth', 'deputy', 'derive',
    'desert', 'design', 'desk', 'despair', 'destroy', 'detail', 'detect', 'device',
    'devote', 'diagram', 'dial', 'diamond', 'diary', 'dice', 'diesel', 'diet',
    'differ', 'digital', 'dignity', 'dilemma', 'dinner', 'dinosaur', 'direct', 'dirt',
    'disagree', 'discover', 'disease', 'dish', 'dismiss', 'disorder', 'display', 'distance',
    'divert', 'divide', 'divorce', 'dizzy', 'doctor', 'document', 'dog', 'doll',
    'dolphin', 'domain', 'donate', 'donkey', 'donor', 'door', 'dose', 'double',
    'dove', 'draft', 'dragon', 'drama', 'drastic', 'draw', 'dream', 'dress',
    'drift', 'drill', 'drink', 'drip', 'drive', 'drop', 'drum', 'dry',
    'duck', 'dune', 'during', 'dust', 'dutch', 'duty', 'dwarf', 'dynamic',
    'eager', 'eagle', 'early', 'earn', 'earth', 'easily', 'east', 'easy',
    'echo', 'ecology', 'economy', 'edge', 'edit', 'educate', 'effort', 'egg',
    'eight', 'either', 'elbow', 'elder', 'electric', 'elegant', 'element', 'elephant',
    'elevator', 'elite', 'else', 'embark', 'embody', 'embrace', 'emerge', 'emotion',
    'employ', 'empower', 'empty', 'enable', 'enact', 'end', 'endless', 'endorse',
    'enemy', 'energy', 'enforce', 'engage', 'engine', 'enhance', 'enjoy', 'enlist',
    'enough', 'enrich', 'enroll', 'ensure', 'enter', 'entire', 'entry', 'envelope',
    'episode', 'equal', 'equip', 'era', 'erase', 'erode', 'erosion', 'error',
    'erupt', 'escape', 'essay', 'essence', 'estate', 'eternal', 'ethics', 'evidence',
    'evil', 'evoke', 'evolve', 'exact', 'example', 'excess', 'exchange', 'excite',
    'exclude', 'excuse', 'execute', 'exercise', 'exhaust', 'exhibit', 'exile', 'exist',
    'exit', 'exotic', 'expand', 'expect', 'expire', 'explain', 'expose', 'express',
    'extend', 'extra', 'eye', 'eyebrow', 'fabric', 'face', 'faculty', 'fade',
    'faint', 'faith', 'fall', 'false', 'fame', 'family', 'famous', 'fan',
    'fancy', 'fantasy', 'farm', 'fashion', 'fat', 'fatal', 'father', 'fatigue',
    'fault', 'favorite', 'feature', 'february', 'federal', 'fee', 'feed', 'feel',
    'female', 'fence', 'festival', 'fetch', 'fever', 'few', 'fiber', 'fiction',
    'field', 'figure', 'file', 'film', 'filter', 'final', 'find', 'fine',
    'finger', 'finish', 'fire', 'firm', 'first', 'fiscal', 'fish', 'fit',
    'fitness', 'fix', 'flag', 'flame', 'flash', 'flat', 'flavor', 'flee',
    'flight', 'flip', 'float', 'flock', 'floor', 'flower', 'fluid', 'flush',
    'fly', 'foam', 'focus', 'fog', 'foil', 'fold', 'follow', 'food',
    'foot', 'force', 'forest', 'forget', 'fork', 'fortune', 'forum', 'forward',
    'fossil', 'foster', 'found', 'fox', 'fragile', 'frame', 'frequent', 'fresh',
    'friend', 'fringe', 'frog', 'front', 'frost', 'frown', 'frozen', 'fruit',
    'fuel', 'fun', 'funny', 'furnace', 'fury', 'future', 'gadget', 'gain',
    'galaxy', 'gallery', 'game', 'gap', 'garage', 'garbage', 'garden', 'garlic',
    'garment', 'gas', 'gasp', 'gate', 'gather', 'gauge', 'gaze', 'general',
    'genius', 'genre', 'gentle', 'genuine', 'gesture', 'ghost', 'giant', 'gift',
    'giggle', 'ginger', 'giraffe', 'girl', 'give', 'glad', 'glance', 'glare',
    'glass', 'glide', 'glimpse', 'globe', 'gloom', 'glory', 'glove', 'glow',
    'glue', 'goat', 'goddess', 'gold', 'good', 'goose', 'gorilla', 'gospel',
    'gossip', 'govern', 'gown', 'grab', 'grace', 'grain', 'grant', 'grape',
    'grass', 'gravity', 'great', 'green', 'grid', 'grief', 'grit', 'grocery',
    'group', 'grow', 'grunt', 'guard', 'guess', 'guide', 'guilt', 'guitar',
    'gun', 'gym', 'habit', 'hair', 'half', 'hammer', 'hamster', 'hand',
    'happy', 'harbor', 'hard', 'harsh', 'harvest', 'hat', 'have', 'hawk',
    'hazard', 'head', 'health', 'heart', 'heavy', 'hedge', 'height', 'hello',
    'helmet', 'help', 'hen', 'hero', 'hidden', 'high', 'hill', 'hint',
    'hip', 'hire', 'history', 'hobby', 'hockey', 'hold', 'hole', 'holiday',
    'hollow', 'home', 'honey', 'hood', 'hope', 'horn', 'horror', 'horse',
    'hospital', 'host', 'hotel', 'hour', 'hover', 'hub', 'huge', 'human',
    'humble', 'humor', 'hundred', 'hungry', 'hunt', 'hurdle', 'hurry', 'hurt',
    'husband', 'hybrid', 'ice', 'icon', 'idea', 'identify', 'idle', 'ignore',
    'ill', 'illegal', 'illness', 'image', 'imitate', 'immense', 'immune', 'impact',
    'impose', 'improve', 'impulse', 'inch', 'include', 'income', 'increase', 'index',
    'indicate', 'indoor', 'industry', 'infant', 'inflict', 'inform', 'inhale', 'inherit',
    'initial', 'inject', 'injury', 'inmate', 'inner', 'innocent', 'input', 'inquiry',
    'insect', 'inside', 'inspire', 'install', 'intact', 'interest', 'into', 'invest',
    'invite', 'involve', 'iron', 'island', 'isolate', 'issue', 'item', 'ivory',
    'jacket', 'jaguar', 'jar', 'jazz', 'jealous', 'denim', 'jelly', 'jewel',
    'job', 'join', 'joke', 'journey', 'joy', 'judge', 'juice', 'jump',
    'jungle', 'junior', 'junk', 'just', 'kangaroo', 'keen', 'keep', 'ketchup',
    'key', 'kick', 'kid', 'kidney', 'kind', 'kingdom', 'kiss', 'kit',
    'kitchen', 'kite', 'kitten', 'kiwi', 'knee', 'knife', 'knock', 'know',
    'lab', 'label', 'labor', 'ladder', 'lady', 'lake', 'lamp', 'language',
    'laptop', 'large', 'later', 'latin', 'laugh', 'laundry', 'lava', 'law',
    'lawn', 'lawsuit', 'layer', 'lazy', 'leader', 'leaf', 'learn', 'leave',
    'lecture', 'left', 'leg', 'legal', 'legend', 'lemon', 'lend', 'length',
    'lens', 'leopard', 'lesson', 'letter', 'level', 'liar', 'liberty', 'library',
    'license', 'life', 'lift', 'light', 'like', 'limb', 'limit', 'link',
    'lion', 'liquid', 'list', 'little', 'live', 'lizard', 'load', 'loan',
    'lobster', 'local', 'lock', 'logic', 'lonely', 'long', 'loop', 'lottery',
    'loud', 'lounge', 'love', 'loyal', 'lucky', 'luggage', 'lumber', 'lunar',
    'lunch', 'luxury', 'lyrics', 'machine', 'mad', 'magic', 'magnet', 'maid',
    'mail', 'main', 'major', 'make', 'mammal', 'man', 'manage', 'mandate',
    'mango', 'mansion', 'manual', 'maple', 'marble', 'march', 'margin', 'marine',
    'market', 'marry', 'mask', 'mass', 'master', 'match', 'material', 'math',
    'matrix', 'matter', 'maximum', 'maze', 'meadow', 'mean', 'measure', 'meat',
    'mechanic', 'medal', 'media', 'melody', 'melon', 'member', 'memory', 'mention',
    'menu', 'mercy', 'merge', 'merit', 'mesh', 'message', 'metal', 'method',
    'middle', 'midnight', 'milk', 'million', 'mimic', 'mind', 'minimum', 'minor',
    'minute', 'miracle', 'mirror', 'misery', 'miss', 'mistake', 'mix', 'mixed',
    'mixture', 'mobile', 'model', 'modify', 'mom', 'moment', 'monitor', 'monkey',
    'monster', 'month', 'moon', 'moral', 'more', 'morning', 'mosquito', 'mother',
    'motion', 'motor', 'mountain', 'mouse', 'move', 'movie', 'much', 'muffin',
    'mule', 'multiply', 'muscle', 'museum', 'mushroom', 'music', 'must', 'mutual',
    'myself', 'mystery', 'myth', 'naive', 'name', 'napkin', 'narrow', 'nasty',
    'nation', 'nature', 'near', 'neck', 'need', 'negative', 'neglect', 'neighbor',
    'nephew', 'nerve', 'nest', 'net', 'network', 'neutral', 'never', 'news',
    'next', 'nice', 'night', 'noble', 'noise', 'nominee', 'noodle', 'normal',
    'north', 'nose', 'notable', 'note', 'nothing', 'notice', 'novel', 'now',
    'number', 'nurse', 'nut', 'oak', 'obey', 'object', 'oblige', 'obscure',
    'observe', 'obtain', 'obvious', 'occur', 'ocean', 'october', 'odor', 'off',
    'offer', 'office', 'often', 'oil', 'okay', 'old', 'olive', 'olympic',
    'omit', 'once', 'one', 'onion', 'online', 'only', 'open', 'opera',
    'opinion', 'oppose', 'option', 'orange', 'orbit', 'orchard', 'order', 'ordinary',
    'organ', 'orient', 'original', 'orphan', 'ostrich', 'other', 'outdoor', 'outer',
    'output', 'outside', 'oval', 'oven', 'over', 'own', 'owner', 'oxygen',
    'oyster', 'ozone', 'pace', 'pack', 'paddle', 'page', 'pair', 'palace',
    'palm', 'panda', 'panel', 'panic', 'panther', 'paper', 'parade', 'parent',
    'park', 'parrot', 'party', 'pass', 'patch', 'path', 'patient', 'patrol',
    'pattern', 'pause', 'pave', 'payment', 'peace', 'peanut', 'pear', 'peasant',
    'pelican', 'pen', 'penalty', 'pencil', 'people', 'pepper', 'perfect', 'permit',
    'person', 'pet', 'phone', 'photo', 'phrase', 'physical', 'piano', 'picnic',
    'picture', 'piece', 'pig', 'pigeon', 'pill', 'pilot', 'pink', 'pioneer',
    'pipe', 'pistol', 'pitch', 'pizza', 'place', 'planet', 'plastic', 'plate',
    'play', 'please', 'pledge', 'pluck', 'plug', 'plunge', 'poem', 'poet',
    'point', 'polar', 'police', 'policy', 'poll', 'pond', 'pony', 'pool',
    'popular', 'portion', 'position', 'possible', 'post', 'potato', 'pottery', 'poverty',
    'powder', 'power', 'practice', 'praise', 'predict', 'prefer', 'prepare', 'present',
    'pretty', 'prevent', 'price', 'pride', 'primary', 'print', 'priority', 'prison',
    'private', 'prize', 'problem', 'process', 'produce', 'profit', 'program', 'project',
    'promote', 'proof', 'property', 'prosper', 'protect', 'proud', 'provide', 'public',
    'pudding', 'pull', 'pulp', 'pulse', 'pumpkin', 'punch', 'pupil', 'puppy',
    'purchase', 'purity', 'purple', 'purpose', 'purse', 'push', 'put', 'puzzle',
    'pyramid', 'quality', 'quantum', 'quarter', 'question', 'quick', 'quit', 'quiz',
    'quote', 'rabbit', 'raccoon', 'race', 'rack', 'radar', 'radio', 'rail',
    'rain', 'raise', 'rally', 'ramp', 'ranch', 'random', 'range', 'rapid',
    'rare', 'rate', 'rather', 'raven', 'raw', 'razor', 'reach', 'react',
    'read', 'real', 'reason', 'rebel', 'rebuild', 'recall', 'receive', 'recipe',
    'record', 'recycle', 'reduce', 'reflect', 'reform', 'refuse', 'region', 'regret',
    'regular', 'reject', 'relax', 'release', 'relief', 'rely', 'remain', 'remember',
    'remind', 'remove', 'render', 'renew', 'rent', 'reopen', 'repair', 'repeat',
    'replace', 'report', 'require', 'rescue', 'resemble', 'resist', 'resource', 'response',
    'result', 'retire', 'retreat', 'return', 'reunion', 'reveal', 'review', 'reward',
    'rhythm', 'rib', 'ribbon', 'rice', 'rich', 'ride', 'ridge', 'rifle',
    'right', 'rigid', 'ring', 'riot', 'ripple', 'risk', 'ritual', 'rival',
    'river', 'road', 'roast', 'robot', 'robust', 'rocket', 'romance', 'roof',
    'rookie', 'room', 'rose', 'rotate', 'rough', 'round', 'route', 'royal',
    'rubber', 'rude', 'rug', 'rule', 'run', 'runway', 'rural', 'sad',
    'saddle', 'sadness', 'safe', 'sail', 'salad', 'salmon', 'salon', 'salt',
    'salute', 'same', 'sample', 'sand', 'satisfy', 'satoshi', 'sauce', 'sausage',
    'save', 'say', 'scale', 'scan', 'scare', 'scatter', 'scene', 'scheme',
    'school', 'science', 'scissors', 'scorpion', 'scout', 'scrap', 'screen', 'script',
    'scrub', 'sea', 'search', 'season', 'seat', 'second', 'secret', 'section',
    'security', 'seed', 'seek', 'segment', 'select', 'sell', 'seminar', 'senior',
    'sense', 'sentence', 'series', 'service', 'session', 'settle', 'setup', 'seven',
    'shadow', 'shaft', 'shallow', 'share', 'shed', 'shell', 'sheriff', 'shield',
    'shift', 'shine', 'ship', 'shirt', 'shock', 'shoe', 'shoot', 'shop',
    'short', 'shoulder', 'shove', 'shrimp', 'shrug', 'shuffle', 'shy', 'sibling',
    'sick', 'side', 'siege', 'sight', 'sign', 'silent', 'silk', 'silly',
    'silver', 'similar', 'simple', 'since', 'sing', 'siren', 'sister', 'situate',
    'six', 'size', 'skate', 'sketch', 'ski', 'skill', 'skin', 'skirt',
    'skull', 'sky', 'slap', 'slate', 'slender', 'slice', 'slide', 'slight',
    'slim', 'slogan', 'slot', 'slow', 'slush', 'small', 'smart', 'smile',
    'smoke', 'smooth', 'snack', 'snake', 'snap', 'sniff', 'snow', 'soap',
    'soccer', 'social', 'sock', 'soda', 'soft', 'solar', 'soldier', 'solid',
    'solution', 'solve', 'someone', 'song', 'soon', 'sorry', 'sort', 'soul',
    'sound', 'soup', 'source', 'south', 'space', 'spare', 'spark', 'speak',
    'special', 'speed', 'spell', 'spend', 'sphere', 'spice', 'spider', 'spike',
    'spin', 'spirit', 'split', 'spoil', 'sponsor', 'spoon', 'sport', 'spot',
    'spray', 'spread', 'spring', 'spy', 'square', 'squeeze', 'squirrel', 'stable',
    'stadium', 'staff', 'stage', 'stairs', 'stamp', 'stand', 'start', 'state',
    'stay', 'steak', 'steel', 'stem', 'step', 'stereo', 'stick', 'still',
    'sting', 'stock', 'stomach', 'stone', 'stool', 'story', 'stove', 'strategy',
    'street', 'strike', 'strong', 'struggle', 'student', 'stuff', 'stumble', 'style',
    'subject', 'submit', 'subway', 'success', 'such', 'sudden', 'suffer', 'sugar',
    'suggest', 'suit', 'summer', 'sun', 'sunny', 'sunset', 'super', 'supply',
    'supreme', 'sure', 'surface', 'surge', 'surprise', 'surround', 'survey', 'suspect',
    'sustain', 'swallow', 'swamp', 'swap', 'swarm', 'swear', 'sweet', 'swift',
    'swim', 'swing', 'switch', 'sword', 'symbol', 'symptom', 'syrup', 'system',
    'table', 'tackle', 'tag', 'tail', 'talent', 'talk', 'tank', 'tape',
    'target', 'task', 'taste', 'tattoo', 'taxi', 'teach', 'team', 'tell',
    'ten', 'tenant', 'tennis', 'tent', 'term', 'test', 'text', 'thank',
    'theme', 'then', 'theory', 'there', 'they', 'thing', 'this', 'thought',
    'three', 'thrive', 'throw', 'thumb', 'thunder', 'ticket', 'tide', 'tiger',
    'tilt', 'timber', 'time', 'tiny', 'tip', 'tired', 'tissue', 'title',
    'toast', 'tobacco', 'today', 'toddler', 'toe', 'together', 'toilet', 'token',
    'tomato', 'tomorrow', 'tone', 'tongue', 'tonight', 'tool', 'tooth', 'top',
    'topic', 'topple', 'torch', 'tornado', 'tortoise', 'toss', 'total', 'tourist',
    'toward', 'tower', 'town', 'toy', 'track', 'trade', 'traffic', 'tragic',
    'train', 'transfer', 'trap', 'trash', 'travel', 'tray', 'treat', 'tree',
    'trend', 'trial', 'tribe', 'trick', 'trigger', 'trim', 'trip', 'trophy',
    'trouble', 'truck', 'true', 'truly', 'trumpet', 'trust', 'truth', 'try',
    'tube', 'tuition', 'tumble', 'tuna', 'tunnel', 'turkey', 'turn', 'turtle',
    'twelve', 'twenty', 'twice', 'twin', 'twist', 'two', 'type', 'typical',
    'ugly', 'umbrella', 'unable', 'unaware', 'uncle', 'uncover', 'under', 'undo',
    'unfair', 'unfold', 'unhappy', 'uniform', 'unique', 'unit', 'universe', 'unknown',
    'unlock', 'until', 'unusual', 'unveil', 'update', 'upgrade', 'uphold', 'upon',
    'upper', 'upset', 'urban', 'urge', 'usage', 'use', 'used', 'useful',
    'useless', 'usual', 'utility', 'vacant', 'vacuum', 'vague', 'valid', 'valley',
    'valve', 'van', 'vanish', 'vapor', 'various', 'vast', 'vault', 'vehicle',
    'velvet', 'vendor', 'venture', 'venue', 'verb', 'verify', 'version', 'very',
    'vessel', 'veteran', 'viable', 'vibrant', 'vicious', 'victory', 'video', 'view',
    'village', 'vintage', 'violin', 'virtual', 'virtue', 'virus', 'visa', 'visit',
    'visual', 'vital', 'vivid', 'vocal', 'voice', 'void', 'volcano', 'volume',
    'vote', 'voter', 'voyage', 'wage', 'wagon', 'wait', 'walk', 'wall',
    'walnut', 'want', 'warfare', 'warm', 'warrior', 'wash', 'wasp', 'waste',
    'water', 'wave', 'way', 'wealth', 'weapon', 'wear', 'weather', 'web',
    'wedding', 'weekend', 'weird', 'welcome', 'west', 'wet', 'whale', 'what',
    'wheat', 'wheel', 'when', 'where', 'whip', 'whisper', 'wide', 'width',
    'wife', 'wild', 'will', 'win', 'window', 'wine', 'wing', 'wink',
    'winner', 'winter', 'wire', 'wisdom', 'wise', 'wish', 'witness', 'wolf',
    'woman', 'wonder', 'wood', 'wool', 'word', 'work', 'world', 'worry',
    'worth', 'wrap', 'wreck', 'wrestle', 'wrist', 'write', 'wrong', 'yard',
    'year', 'yellow', 'you', 'young', 'youth', 'zebra', 'zero', 'zone', 'zoo'
  ];

  // ── CSPRNG Integer ──────────────────────────────────────────
  static int _secureInt(int max) {
    if (max <= 0) return 0;
    return _secureRandom.nextInt(max);
  }

  // ── CSPRNG Fisher-Yates Shuffle ─────────────────────────────
  static List<T> _shuffle<T>(List<T> list) {
    final copy = List<T>.from(list);
    for (int i = copy.length - 1; i > 0; i--) {
      final j = _secureInt(i + 1);
      final temp = copy[i];
      copy[i] = copy[j];
      copy[j] = temp;
    }
    return copy;
  }

  // ── Standard Password Generator ─────────────────────────────
  static String generatePassword({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
    bool excludeAmbiguous = false,
  }) {
    final List<String> activeSets = [];

    String u = upperChars;
    String l = lowerChars;
    String n = numChars;
    String s = symbolChars;

    if (excludeAmbiguous) {
      u = u.replaceAll(_ambiguousRegex, '');
      l = l.replaceAll(_ambiguousRegex, '');
      n = n.replaceAll(_ambiguousRegex, '');
      s = s.replaceAll(_ambiguousRegex, '');
    }

    if (uppercase) activeSets.add(u);
    if (lowercase) activeSets.add(l);
    if (numbers) activeSets.add(n);
    if (symbols) activeSets.add(s);

    if (activeSets.isEmpty) {
      activeSets.add(l);
    }

    final pool = activeSets.join('');
    final List<String> guaranteed = [];

    // Ensure at least 1 character from each active set
    for (final set in activeSets) {
      if (set.isNotEmpty) {
        guaranteed.add(set[_secureInt(set.length)]);
      }
    }

    final int remainingLen = max(0, length - guaranteed.length);
    final List<String> rest = List.generate(
      remainingLen,
      (_) => pool[_secureInt(pool.length)],
    );

    return _shuffle([...guaranteed, ...rest]).join('');
  }

  // ── Diceware Passphrase Generator ───────────────────────────
  static String generatePassphrase({
    int wordCount = 4,
    String separator = '-',
    bool capitalize = true,
    bool includeNumber = true,
  }) {
    final List<String> words = List.generate(wordCount, (_) {
      final rawWord = effWords[_secureInt(effWords.length)];
      if (capitalize && rawWord.isNotEmpty) {
        return rawWord[0].toUpperCase() + rawWord.substring(1);
      }
      return rawWord;
    });

    if (includeNumber && words.isNotEmpty) {
      final targetIdx = _secureInt(words.length);
      words[targetIdx] += _secureInt(100).toString();
    }

    return words.join(separator);
  }

  // ── Entropy & Crack Time Calculations ──────────────────────
  static int calcEntropyBits({
    required bool isPassphrase,
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
    bool excludeAmbiguous = false,
    int wordCount = 4,
    bool includeNumber = true,
  }) {
    if (!isPassphrase) {
      int poolSize = 0;
      int u = upperChars.length;
      int l = lowerChars.length;
      int n = numChars.length;
      int s = symbolChars.length;

      if (excludeAmbiguous) {
        u = upperChars.replaceAll(_ambiguousRegex, '').length;
        l = lowerChars.replaceAll(_ambiguousRegex, '').length;
        n = numChars.replaceAll(_ambiguousRegex, '').length;
        s = symbolChars.replaceAll(_ambiguousRegex, '').length;
      }

      if (uppercase) poolSize += u;
      if (lowercase) poolSize += l;
      if (numbers) poolSize += n;
      if (symbols) poolSize += s;

      if (poolSize <= 0 || length <= 0) return 0;
      return (length * (log(poolSize) / log(2))).floor();
    } else {
      final wordlistSize = effWords.length;
      double bits = wordCount * (log(wordlistSize) / log(2));
      if (includeNumber) bits += (log(100) / log(2));
      return bits.floor();
    }
  }

  /// GPU cluster crack time estimator assuming 100 Billion (10^11) guesses/sec
  static String estimateCrackTime(int bits) {
    if (bits <= 0) return 'Instant';
    final double combinations = pow(2, bits).toDouble();
    final double seconds = combinations / 1e11;

    if (seconds < 1) return 'Instant';
    if (seconds < 60) return '${seconds.round()} seconds';
    if (seconds < 3600) return '${(seconds / 60).round()} minutes';
    if (seconds < 86400) return '${(seconds / 3600).round()} hours';
    if (seconds < 31536000) return '${(seconds / 86400).round()} days';
    if (seconds < 31536000 * 100) return '${(seconds / 31536000).round()} years';
    if (seconds < 31536000 * 1e6) {
      return '${(seconds / (31536000 * 1e3)).toStringAsFixed(1)}k years';
    }
    return '${(seconds / (31536000 * 1e6)).toStringAsFixed(1)}M+ years';
  }

  static String strengthLabel(int bits) {
    if (bits < 35) return 'Weak';
    if (bits < 60) return 'Fair';
    if (bits < 80) return 'Strong';
    return 'Very Strong';
  }

  static double strengthProgress(int bits) {
    return (bits / 120.0).clamp(0.0, 1.0);
  }
}
